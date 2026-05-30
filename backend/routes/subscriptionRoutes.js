const express = require("express");
const subscriptionController = require("../controllers/subscriptionController");
const { auth } = require("../middleware/authMiddleware");

const router = express.Router();

// Apply auth middleware to all routes
router.use(auth);

router.route("/")
  .get(subscriptionController.getSubscriptions)
  .post(subscriptionController.createSubscription);

router.route("/rescan")
  .post(subscriptionController.rescan);

router.route("/:id")
  .patch(subscriptionController.toggleSubscription);

module.exports = router;
