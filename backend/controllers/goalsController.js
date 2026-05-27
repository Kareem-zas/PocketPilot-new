const Goal = require("../models/Goal");
const User = require("../models/User");
const catchAsync = require("../utils/catchAsync");
const AppError = require("../utils/AppError");

/* =========================
   GET ALL GOALS (PERSONAL & SHARED)
========================= */
exports.getGoals = catchAsync(async (req, res, next) => {
  const goals = await Goal.find({
    $or: [{ user: req.userId }, { members: req.userId }],
  })
    .sort({ createdAt: -1 })
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  // Build summary stats
  const totalSaved = goals.reduce((sum, g) => sum + g.savedAmount, 0);
  const totalTarget = goals.reduce((sum, g) => sum + g.targetAmount, 0);
  const overallProgress = totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0;

  res.status(200).json({
    status: "success",
    data: {
      goals,
      summary: {
        totalSaved,
        totalTarget,
        overallProgress: Math.round(overallProgress),
        goalsCount: goals.length,
      },
    },
  });
});

/* =========================
   CREATE GOAL
========================= */
exports.createGoal = catchAsync(async (req, res, next) => {
  const { title, category, targetAmount, targetDate, initialDeposit } = req.body;

  if (!title || !targetAmount || !targetDate) {
    return next(new AppError("Please provide title, targetAmount, and targetDate", 400));
  }

  const savedAmount = initialDeposit && initialDeposit > 0 ? initialDeposit : 0;

  const goal = await Goal.create({
    user: req.userId,
    title,
    category: category || "General",
    targetAmount,
    savedAmount,
    targetDate: new Date(targetDate),
    members: [],
    contributions: savedAmount > 0 ? [{ userId: req.userId, amount: savedAmount, createdAt: new Date() }] : [],
    shared: false,
  });

  const populatedGoal = await Goal.findById(goal._id)
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  res.status(201).json({
    status: "success",
    data: { goal: populatedGoal },
  });
});

/* =========================
   GET SINGLE GOAL
========================= */
exports.getGoal = catchAsync(async (req, res, next) => {
  const goal = await Goal.findOne({
    _id: req.params.id,
    $or: [{ user: req.userId }, { members: req.userId }],
  })
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  if (!goal) {
    return next(new AppError("Goal not found", 404));
  }

  res.status(200).json({
    status: "success",
    data: { goal },
  });
});

/* =========================
   ADD SAVINGS TO GOAL
========================= */
exports.addSavings = catchAsync(async (req, res, next) => {
  const { amount } = req.body;

  if (!amount || amount <= 0) {
    return next(new AppError("Please provide a valid amount", 400));
  }

  const goal = await Goal.findOne({
    _id: req.params.id,
    $or: [{ user: req.userId }, { members: req.userId }],
  });

  if (!goal) {
    return next(new AppError("Goal not found", 404));
  }

  goal.savedAmount += amount;

  // Add savings contribution for this user
  const contribIndex = goal.contributions.findIndex(
    (c) => c.userId.toString() === req.userId
  );

  if (contribIndex > -1) {
    goal.contributions[contribIndex].amount += amount;
    goal.contributions[contribIndex].createdAt = new Date();
  } else {
    goal.contributions.push({
      userId: req.userId,
      amount,
      createdAt: new Date(),
    });
  }

  // Auto-complete if target reached
  if (goal.savedAmount >= goal.targetAmount) {
    goal.isCompleted = true;
    goal.savedAmount = goal.targetAmount;
  }

  await goal.save();

  const populatedGoal = await Goal.findById(goal._id)
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  const io = req.app.get("io");
  if (io) {
    io.to(`goal_${goal._id}`).emit("goalUpdated", { goalId: goal._id.toString() });
  }

  res.status(200).json({
    status: "success",
    data: { goal: populatedGoal },
  });
});

/* =========================
   UPDATE GOAL
========================= */
exports.updateGoal = catchAsync(async (req, res, next) => {
  const { title, category, targetAmount, targetDate } = req.body;

  const goal = await Goal.findOneAndUpdate(
    { _id: req.params.id, user: req.userId }, // Creator only can update goal settings
    { title, category, targetAmount, targetDate },
    { new: true, runValidators: true }
  )
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  if (!goal) {
    return next(new AppError("Goal not found or unauthorized", 404));
  }

  res.status(200).json({
    status: "success",
    data: { goal },
  });
});

/* =========================
   DELETE GOAL
========================= */
exports.deleteGoal = catchAsync(async (req, res, next) => {
  const goal = await Goal.findOneAndDelete({
    _id: req.params.id,
    user: req.userId, // Creator only can delete
  });

  if (!goal) {
    return next(new AppError("Goal not found or unauthorized", 404));
  }

  res.status(200).json({
    status: "success",
    message: "Goal deleted successfully",
  });
});

/* =========================
   INVITE MEMBER TO SHARED GOAL
========================= */
exports.inviteMember = catchAsync(async (req, res, next) => {
  const { goalId, email } = req.body;

  if (!goalId || !email) {
    return next(new AppError("Please provide goalId and email", 400));
  }

  const friend = await User.findOne({ email: email.toLowerCase() });
  if (!friend) {
    return next(new AppError("User with this email not found", 404));
  }

  if (friend._id.toString() === req.userId) {
    return next(new AppError("You cannot invite yourself to a goal", 400));
  }

  const goal = await Goal.findOne({
    _id: goalId,
    $or: [{ user: req.userId }, { members: req.userId }],
  });

  if (!goal) {
    return next(new AppError("Goal not found", 404));
  }

  // Add to members if not already present
  if (!goal.members.includes(friend._id)) {
    goal.members.push(friend._id);
  }
  goal.shared = true;

  await goal.save();

  const populatedGoal = await Goal.findById(goal._id)
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  res.status(200).json({
    status: "success",
    data: { goal: populatedGoal },
  });
});

/* =========================
   CONTRIBUTE TO SHARED GOAL
========================= */
exports.contributeToGoal = catchAsync(async (req, res, next) => {
  const { amount } = req.body;
  const goalId = req.params.id;

  if (!amount || amount <= 0) {
    return next(new AppError("Please provide a valid amount", 400));
  }

  const goal = await Goal.findOne({
    _id: goalId,
    $or: [{ user: req.userId }, { members: req.userId }],
  });

  if (!goal) {
    return next(new AppError("Goal not found", 404));
  }

  goal.savedAmount += amount;

  // Add savings contribution for this user
  const contribIndex = goal.contributions.findIndex(
    (c) => c.userId.toString() === req.userId
  );

  if (contribIndex > -1) {
    goal.contributions[contribIndex].amount += amount;
    goal.contributions[contribIndex].createdAt = new Date();
  } else {
    goal.contributions.push({
      userId: req.userId,
      amount,
      createdAt: new Date(),
    });
  }

  // Auto-complete if target reached
  if (goal.savedAmount >= goal.targetAmount) {
    goal.isCompleted = true;
    goal.savedAmount = goal.targetAmount;
  }

  await goal.save();

  const populatedGoal = await Goal.findById(goal._id)
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  const io = req.app.get("io");
  if (io) {
    io.to(`goal_${goal._id}`).emit("goalUpdated", { goalId: goal._id.toString() });
  }

  res.status(200).json({
    status: "success",
    data: { goal: populatedGoal },
  });
});

/* =========================
   GET SHARED GOALS
========================= */
exports.getSharedGoals = catchAsync(async (req, res, next) => {
  const goals = await Goal.find({
    $or: [{ user: req.userId }, { members: req.userId }],
    shared: true,
  })
    .sort({ createdAt: -1 })
    .populate("user", "fullName email")
    .populate("members", "fullName email")
    .populate("contributions.userId", "fullName email");

  res.status(200).json({
    status: "success",
    data: { goals },
  });
});
