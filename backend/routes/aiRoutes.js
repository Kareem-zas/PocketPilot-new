const express = require("express");
const router = express.Router();
const { processChat, processReceipt } = require("../controllers/aiController");
const { auth } = require("../middleware/authMiddleware");

// Both endpoints are protected by auth middleware
router.post("/chat", auth, processChat);
router.post("/receipt", auth, processReceipt);

module.exports = router;
