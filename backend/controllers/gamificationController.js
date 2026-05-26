const mongoose = require("mongoose");
const User = require("../models/User");
const VariableExpense = require("../models/variableExpenses");
const Goal = require("../models/Goal");
const Subscription = require("../models/Subscription");
const catchAsync = require("../utils/catchAsync");

exports.getGamification = catchAsync(async (req, res, next) => {
  const user = await User.findById(req.userId);
  if (!user) {
    return res.status(404).json({ status: "fail", message: "User not found" });
  }

  // Calculate dynamic daily budget
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);

  const [varAggMonth] = await VariableExpense.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(req.userId),
        date: { $gte: startOfMonth, $lte: endOfToday },
      },
    },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const expensesMonth = varAggMonth?.total || 0;

  const [varAggToday] = await VariableExpense.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(req.userId),
        date: { $gte: startOfToday, $lte: endOfToday },
      },
    },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const expensesToday = varAggToday?.total || 0;

  const totalDaysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const currentDay = now.getDate();
  const remainingDays = totalDaysInMonth - currentDay + 1;
  const remainingBudget = user.monthlyBudget - expensesMonth;
  const dailyBudget = Math.max(0, remainingBudget / remainingDays);

  res.status(200).json({
    status: "success",
    data: {
      streakDays: user.streakDays || 0,
      unlockedBadges: user.unlockedBadges || [],
      lastBudgetSuccessDate: user.lastBudgetSuccessDate,
      monthlyBudget: user.monthlyBudget,
      dailyBudget: Math.round(dailyBudget * 100) / 100,
      remainingBudget: Math.round(remainingBudget * 100) / 100,
      expensesToday: Math.round(expensesToday * 100) / 100,
    },
  });
});

exports.checkGamification = catchAsync(async (req, res, next) => {
  const user = await User.findById(req.userId);
  if (!user) {
    return res.status(404).json({ status: "fail", message: "User not found" });
  }

  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);

  const [varAggMonth] = await VariableExpense.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(req.userId),
        date: { $gte: startOfMonth, $lte: endOfToday },
      },
    },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const expensesMonth = varAggMonth?.total || 0;

  const [varAggToday] = await VariableExpense.aggregate([
    {
      $match: {
        user: new mongoose.Types.ObjectId(req.userId),
        date: { $gte: startOfToday, $lte: endOfToday },
      },
    },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const expensesToday = varAggToday?.total || 0;

  const totalDaysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const currentDay = now.getDate();
  const remainingDays = totalDaysInMonth - currentDay + 1;
  const remainingBudget = user.monthlyBudget - expensesMonth;
  const dailyBudget = Math.max(0, remainingBudget / remainingDays);

  const success = expensesToday <= dailyBudget;
  let streakDays = user.streakDays || 0;
  const lastSuccess = user.lastBudgetSuccessDate;
  const todayStr = now.toDateString();

  if (success) {
    if (!lastSuccess) {
      streakDays = 1;
      user.lastBudgetSuccessDate = now;
    } else {
      const lastSuccessStr = new Date(lastSuccess).toDateString();
      if (lastSuccessStr === todayStr) {
        // Already succeeded today, keep current streak
      } else {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toDateString();
        if (lastSuccessStr === yesterdayStr) {
          streakDays += 1;
        } else {
          streakDays = 1;
        }
        user.lastBudgetSuccessDate = now;
      }
    }
  } else {
    // If they already recorded success today but just added an expense that breaks it
    streakDays = 0;
  }
  user.streakDays = streakDays;

  // Badge check
  const newlyUnlocked = [];
  const unlocked = new Set(user.unlockedBadges || []);

  const evaluateAndUnlock = (badgeName) => {
    if (!unlocked.has(badgeName)) {
      newlyUnlocked.push(badgeName);
      unlocked.add(badgeName);
    }
  };

  if (streakDays >= 3) evaluateAndUnlock("Pocket Saver");
  if (streakDays >= 7) evaluateAndUnlock("Budget Master");
  if (streakDays >= 30) evaluateAndUnlock("Financial Ninja");

  // No-Spend Hero: check if at least one day has zero variable expenses since account creation
  const daysSinceCreation = Math.max(1, Math.ceil((now - user.createdAt) / (1000 * 60 * 60 * 24)));
  const distinctDates = await VariableExpense.distinct("date", { user: user._id });
  const uniqueDays = new Set(distinctDates.map((d) => new Date(d).toDateString()));
  if (uniqueDays.size < daysSinceCreation || expensesToday === 0) {
    evaluateAndUnlock("No-Spend Hero");
  }

  // Smart Planner: user has at least one active goal
  const goalsCount = await Goal.countDocuments({ user: user._id });
  if (goalsCount > 0) {
    evaluateAndUnlock("Smart Planner");
  }

  // Subscription Hunter: user has at least one active subscription
  const subCount = await Subscription.countDocuments({ user: user._id, isActive: true });
  if (subCount > 0) {
    evaluateAndUnlock("Subscription Hunter");
  }

  if (newlyUnlocked.length > 0) {
    user.unlockedBadges = Array.from(unlocked);
  }

  await user.save();

  res.status(200).json({
    status: "success",
    data: {
      streakDays: user.streakDays,
      unlockedBadges: user.unlockedBadges,
      lastBudgetSuccessDate: user.lastBudgetSuccessDate,
      monthlyBudget: user.monthlyBudget,
      dailyBudget: Math.round(dailyBudget * 100) / 100,
      remainingBudget: Math.round(remainingBudget * 100) / 100,
      expensesToday: Math.round(expensesToday * 100) / 100,
      newlyUnlocked,
    },
  });
});
