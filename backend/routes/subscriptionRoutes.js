const express = require("express");
const subscriptionController = require("../controllers/subscriptionController");
const { auth } = require("../middleware/authMiddleware");

const router = express.Router();

// Apply auth middleware to all routes
router.use(auth);

router.route("/")
  .get(subscriptionController.getSubscriptions);

router.route("/rescan")
  .post(subscriptionController.rescan);

router.route("/:id/cancel")
  .patch(subscriptionController.cancelSubscription);

module.exports = router;
