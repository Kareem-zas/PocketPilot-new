const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/authMiddleware");

const {
  getGoals,
  createGoal,
  getGoal,
  addSavings,
  updateGoal,
  deleteGoal,
  inviteMember,
  contributeToGoal,
  getSharedGoals,
} = require("../controllers/goalsController");

// Shared goals specific routes (Must be registered before /:id)
router.get("/shared", auth, getSharedGoals);
router.post("/invite", auth, inviteMember);
router.post("/:id/contribute", auth, contributeToGoal);

// GET all goals + summary  |  POST create new goal
router.route("/").get(auth, getGoals).post(auth, createGoal);

// GET / UPDATE / DELETE a specific goal
router.route("/:id").get(auth, getGoal).patch(auth, updateGoal).delete(auth, deleteGoal);

// Add savings deposit to a goal
router.post("/:id/save", auth, addSavings);

module.exports = router;
