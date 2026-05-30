const express = require("express");
const smsController = require("../controllers/smsController");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Protect all routes
router.use(authMiddleware.auth);

router.post("/process", smsController.processSMS);

module.exports = router;
