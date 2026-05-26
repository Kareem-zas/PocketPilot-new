const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware");
const { getGamification, checkGamification } = require("../controllers/gamificationController");

router.get("/", auth, getGamification);
router.post("/check", auth, checkGamification);

module.exports = router;
