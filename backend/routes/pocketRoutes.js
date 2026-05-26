const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware");
const {
  getPocketBalance,
  updatePocketBalance,
  addPocketCash,
  subtractPocketCash,
} = require("../controllers/pocketController");

router.use(auth);

router.get("/", getPocketBalance);
router.put("/", updatePocketBalance);
router.post("/add", addPocketCash);
router.post("/subtract", subtractPocketCash);

module.exports = router;
