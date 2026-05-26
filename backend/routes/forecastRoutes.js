const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware");
const { getForecast } = require("../controllers/forecastController");

router.get("/", auth, getForecast);

module.exports = router;
