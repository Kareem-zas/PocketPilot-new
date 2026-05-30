const User = require("../models/User");
const VariableExpense = require("../models/variableExpenses");
const Income = require("../models/income");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");
const geminiRotator = require("../utils/geminiRotator");

exports.processSMS = catchAsync(async (req, res, next) => {
  const { rawBody, sender, smsId, smsDate, lat, lng } = req.body;

  if (!rawBody || !smsId) {
    return next(new AppError("rawBody and smsId are required", 400));
  }

  // 1. Deduplication Check: Check if SMS is already processed
  const existingExpense = await VariableExpense.findOne({ smsId });
  const existingIncome = await Income.findOne({ smsId });

  if (existingExpense || existingIncome) {
    return res.status(200).json({
      status: "success",
      message: "SMS already processed",
      data: null
    });
  }

  // 2. Process SMS using Gemini
  const model = geminiRotator.getAI().getGenerativeModel({ model: "gemini-2.5-flash" });

  const prompt = `
    Analyze the following bank SMS message.
    Extract the transaction details and return EXACTLY a JSON object with no markdown formatting and no extra text.
    The JSON object must have these exact keys:
    - "amount": a number representing the transaction amount
    - "currency": the currency symbol or code
    - "type": must be exactly one of "expense", "income", or "withdrawal"
    - "merchant_name": the name of the store, person, or entity involved. If withdrawal, use "ATM Withdrawal".
    
    Rules for type:
    - If money was deducted, spent, or paid: "expense"
    - If money was added, deposited, or received: "income"
    - If money was withdrawn as cash from an ATM: "withdrawal"
    - If the message is an OTP (One-Time Password), verification code, or just an alert without actual confirmed transaction: "ignore"
    
    SMS from ${sender}:
    "${rawBody}"
  `;

  let parsedData;
  try {
    const result = await model.generateContent(prompt);
    let text = result.response.text().trim();

    // Clean up markdown block if present
    if (text.startsWith("\`\`\`json")) {
      text = text.replace(/^\`\`\`json/, "").replace(/\`\`\`$/, "").trim();
    } else if (text.startsWith("\`\`\`")) {
      text = text.replace(/^\`\`\`/, "").replace(/\`\`\`$/, "").trim();
    }

    parsedData = JSON.parse(text);
  } catch (error) {
    console.error("Gemini Parsing Error:", error);
    return next(new AppError("Failed to parse SMS with AI: " + error.message, 500));
  }

  const { amount, type, merchant_name } = parsedData;

  // Basic validation of parsed data
  if (type === "ignore") {
    return res.status(200).json({ status: "success", message: "Ignored OTP or non-transactional SMS" });
  }

  if (typeof amount !== "number" || amount <= 0 || !["expense", "income", "withdrawal"].includes(type)) {
    return next(new AppError("AI could not confidently parse the transaction", 400));
  }

  // 2.5 Smart Deduplication: Check if there's an identical transaction within the last 5 minutes
  const fiveMinsAgo = new Date(Date.now() - 5 * 60 * 1000);
  
  if (type === "withdrawal" || type === "expense") {
    const titleToCheck = type === "withdrawal" ? "ATM Withdrawal" : (merchant_name || "Payment");
    const duplicate = await VariableExpense.findOne({
      user: req.userId,
      title: titleToCheck,
      amount: amount,
      date: { $gte: fiveMinsAgo }
    });
    
    if (duplicate) {
      return res.status(200).json({ status: "success", message: "Duplicate transaction ignored" });
    }
  } else if (type === "income") {
    const duplicate = await Income.findOne({
      user: req.userId,
      source: merchant_name || "Bank Transfer",
      amount: amount,
      date: { $gte: fiveMinsAgo }
    });
    
    if (duplicate) {
      return res.status(200).json({ status: "success", message: "Duplicate transaction ignored" });
    }
  }

  let savedRecord;

  // 3. Reverse Geocode the location if lat/lng are provided and not 0
  let locationString = "";
  if (lat && lng && lat !== 0 && lng !== 0) {
    try {
      const geoUrl = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`;
      const geoRes = await fetch(geoUrl, {
        headers: { "User-Agent": "PocketPilotApp/1.0" }
      });
      const geoData = await geoRes.json();
      if (geoData && geoData.display_name) {
        // Just take the first 2 or 3 parts of the address for brevity
        const parts = geoData.display_name.split(",");
        locationString = parts.slice(0, 3).join(",").trim();
      } else {
        locationString = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
      }
    } catch (e) {
      console.error("Geocoding failed:", e);
      locationString = `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
    }
  } else {
    locationString = "Unknown location";
  }

  // 4. Save to appropriate collection
  const recordDate = smsDate ? new Date(smsDate) : new Date();

  if (type === "withdrawal") {
    // 4a. Add to pocket cash AND log an expense
    await User.findByIdAndUpdate(req.userId, { $inc: { pocketBalance: amount } });

    savedRecord = await VariableExpense.create({
      user: req.userId,
      title: "ATM Withdrawal",
      amount: amount,
      category: "cash",
      notes: `Auto-detected withdrawal from ${sender}. Added to Pocket Cash. Location: ${locationString}`,
      smsId: smsId,
      date: recordDate
    });
  } else if (type === "expense") {
    // 4b. Log standard expense
    savedRecord = await VariableExpense.create({
      user: req.userId,
      title: merchant_name || "Payment",
      amount: amount,
      category: "other", // Default, could be enhanced with Gemini categorizing it
      notes: `Auto-detected payment from ${sender}. Location: ${locationString}`,
      smsId: smsId,
      date: recordDate
    });
  } else if (type === "income") {
    // 4c. Log income
    savedRecord = await Income.create({
      user: req.userId,
      source: merchant_name || "Bank Transfer",
      amount: amount,
      notes: `Auto-detected income from ${sender}. Location: ${locationString}`,
      smsId: smsId,
      date: recordDate
    });
  }

  res.status(201).json({
    status: "success",
    message: `Successfully processed ${type}`,
    data: savedRecord,
    parsed: parsedData
  });
});
