const express = require("express");
const router = express.Router();
const dashboardController = require("../controllers/dashboardController");
const { auth } = require("../middleware/authMiddleware");

// GET /api/dashboard?year=2023&month=10
router.get("/", auth, dashboardController.getDashboard);

module.exports = router;