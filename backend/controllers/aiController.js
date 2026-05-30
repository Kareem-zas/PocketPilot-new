const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");
const geminiRotator = require("../utils/geminiRotator");

exports.processChat = catchAsync(async (req, res, next) => {
  const { prompt } = req.body;

  if (!prompt) {
    return next(new AppError("Prompt is required", 400));
  }

  try {
    const model = geminiRotator.getAI().getGenerativeModel({ model: "gemini-2.5-flash" });
    const result = await model.generateContent(prompt);
    const responseText = result.response.text();

    res.status(200).json({
      status: "success",
      data: {
        response: responseText
      }
    });
  } catch (error) {
    console.error("Gemini Chat Error:", error);
    return next(new AppError("Failed to process chat: " + error.message, 500));
  }
});

exports.processReceipt = catchAsync(async (req, res, next) => {
  const { imageBase64, prompt } = req.body;

  if (!imageBase64) {
    return next(new AppError("Image base64 is required", 400));
  }

  try {
    const model = geminiRotator.getAI().getGenerativeModel({ model: "gemini-2.5-flash" });
    
    // Construct the payload for Gemini Vision
    const imagePart = {
      inlineData: {
        data: imageBase64,
        mimeType: "image/jpeg" // Adjust if needed, but Gemini handles raw base64 well
      }
    };

    const defaultPrompt = `Analyze this receipt. Extract the following information and return EXACTLY a JSON object:
    {
      "merchantName": "Name of the store",
      "totalAmount": 0.0,
      "date": "YYYY-MM-DD",
      "category": "Food, Electronics, etc.",
      "items": [{"name": "Item 1", "price": 0.0}]
    }`;

    const finalPrompt = prompt || defaultPrompt;

    const result = await model.generateContent([finalPrompt, imagePart]);
    let text = result.response.text().trim();

    // Clean markdown
    if (text.startsWith("\`\`\`json")) text = text.replace(/^\`\`\`json/, "").replace(/\`\`\`$/, "").trim();
    else if (text.startsWith("\`\`\`")) text = text.replace(/^\`\`\`/, "").replace(/\`\`\`$/, "").trim();

    const parsedData = JSON.parse(text);

    res.status(200).json({
      status: "success",
      data: parsedData
    });
  } catch (error) {
    console.error("Gemini Receipt Error:", error);
    return next(new AppError("Failed to process receipt: " + error.message, 500));
  }
});
