const Subscription = require("../models/Subscription");
const VariableExpense = require("../models/variableExpenses");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   DETECTION LOGIC
========================= */
exports.runDetection = async (userId) => {
  try {
    // 1. Fetch all variable expenses for user, sorted by date descending
    const expenses = await VariableExpense.find({ user: userId }).sort({ date: -1 });

    if (!expenses || expenses.length < 2) return;

    // 2. Group by title (vendor)
    const grouped = {};
    expenses.forEach((exp) => {
      const vendor = exp.title.trim().toLowerCase();
      if (!grouped[vendor]) grouped[vendor] = [];
      grouped[vendor].push(exp);
    });

    // 3. Analyze each vendor group
    for (const vendor in grouped) {
      const vendorExpenses = grouped[vendor];
      if (vendorExpenses.length < 2) continue;

      let subscriptionDetected = false;
      let detectedAmount = 0;
      let lastTxnDate = null;
      let firstTxnDate = vendorExpenses[vendorExpenses.length - 1].date;

      // Loop through sorted transactions to find a consecutive pair matching criteria
      for (let i = 0; i < vendorExpenses.length - 1; i++) {
        const newerTxn = vendorExpenses[i];
        const olderTxn = vendorExpenses[i + 1];

        const daysDiff = Math.abs(newerTxn.date - olderTxn.date) / (1000 * 60 * 60 * 24);

        // 10% tolerance
        const maxAmount = Math.max(newerTxn.amount, olderTxn.amount);
        const amountDiff = Math.abs(newerTxn.amount - olderTxn.amount);
        const withinTolerance = amountDiff <= 0.10 * maxAmount;

        // Roughly monthly: 28 to 32 days
        if (daysDiff >= 28 && daysDiff <= 32 && withinTolerance) {
          subscriptionDetected = true;
          detectedAmount = newerTxn.amount; // Use latest amount
          lastTxnDate = newerTxn.date;
          break;
        }
      }

      if (subscriptionDetected) {
        // Check if already tracked
        const existing = await Subscription.findOne({ user: userId, vendor: vendor });

        if (!existing) {
          // Calculate next expected date (30 days from the last transaction we found)
          const nextExpected = new Date(lastTxnDate);
          nextExpected.setDate(nextExpected.getDate() + 30);

          await Subscription.create({
            user: userId,
            vendor: vendor,
            amount: detectedAmount,
            frequency: "monthly",
            firstDetectedDate: firstTxnDate,
            nextExpectedDate: nextExpected,
            isActive: true,
          });
          console.log(`[Subscription Radar] Detected new subscription for user ${userId}: ${vendor} ($${detectedAmount})`);
        }
      }
    }
  } catch (error) {
    console.error(`[Subscription Radar] Error running detection for user ${userId}:`, error);
  }
};

/* =========================
   RESCAN SUBSCRIPTIONS
========================= */
exports.rescan = catchAsync(async (req, res, next) => {
  await exports.runDetection(req.userId);
  res.status(200).json({
    status: "success",
    message: "Rescan completed",
  });
});

/* =========================
   GET ALL SUBSCRIPTIONS
========================= */
exports.getSubscriptions = catchAsync(async (req, res, next) => {
  const subscriptions = await Subscription.find({
    user: req.userId,
    // Return all subscriptions, even inactive ones, so the UI can toggle them back on
  }).sort({ nextExpectedDate: 1 });

  res.status(200).json({
    status: "success",
    data: {
      subscriptions,
    },
  });
});

/* =========================
   CREATE SUBSCRIPTION (MANUAL)
========================= */
exports.createSubscription = catchAsync(async (req, res, next) => {
  const { title, vendor, amount, frequency, startDate, isActive } = req.body;
  
  // Accept title or vendor (legacy client uses title)
  const subVendor = vendor || title;
  
  if (!subVendor || !amount || !startDate) {
    return next(new AppError("Please provide vendor, amount, and startDate", 400));
  }

  const start = new Date(startDate);
  const nextExpected = new Date(start);
  
  const freq = (frequency || "monthly").toLowerCase();
  if (freq === "weekly") {
    nextExpected.setDate(nextExpected.getDate() + 7);
  } else if (freq === "yearly") {
    nextExpected.setFullYear(nextExpected.getFullYear() + 1);
  } else {
    // Default to monthly
    nextExpected.setMonth(nextExpected.getMonth() + 1);
  }

  const newSub = await Subscription.create({
    user: req.userId,
    vendor: subVendor,
    amount: amount,
    frequency: freq,
    firstDetectedDate: start,
    nextExpectedDate: nextExpected,
    isActive: isActive !== undefined ? isActive : true,
  });

  res.status(201).json({
    status: "success",
    data: {
      subscription: newSub,
    },
  });
});

/* =========================
   TOGGLE SUBSCRIPTION ACTIVITY
========================= */
exports.toggleSubscription = catchAsync(async (req, res, next) => {
  const { isActive } = req.body;
  
  const sub = await Subscription.findOneAndUpdate(
    { _id: req.params.id, user: req.userId },
    { isActive: isActive },
    { new: true, runValidators: true }
  );

  if (!sub) {
    return next(new AppError("Subscription not found", 404));
  }

  res.status(200).json({
    status: "success",
    message: "Subscription updated.",
    data: { subscription: sub },
  });
});
