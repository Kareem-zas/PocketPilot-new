const mongoose = require("mongoose");
const Income = require("../models/income");
const VariableExpense = require("../models/variableExpenses");
const Subscription = require("../models/Subscription");

const calculateSubscriptionForMonth = (subscriptions, year, monthIndex) => {
  const endOfMonth = new Date(year, monthIndex + 1, 1);

  return subscriptions.reduce((total, sub) => {
    if (!sub.isActive) return total;
    if (new Date(sub.firstDetectedDate) >= endOfMonth) return total;

    if (sub.frequency === "yearly") {
      const start = new Date(sub.firstDetectedDate);
      if (start.getMonth() !== monthIndex) return total;
      return total + sub.amount;
    } else if (sub.frequency === "monthly") {
      return total + sub.amount;
    } else if (sub.frequency === "bi-weekly") {
      return total + (sub.amount * 2);
    } else if (sub.frequency === "weekly") {
      return total + (sub.amount * 4);
    }
    return total;
  }, 0);
};

const computeBalanceAtDate = async (userId, subscriptions, date) => {
  const objId = new mongoose.Types.ObjectId(userId);

  const [incomeAgg] = await Income.aggregate([
    { $match: { user: objId, date: { $lte: date } } },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const totalIncome = incomeAgg?.total || 0;

  const [varAgg] = await VariableExpense.aggregate([
    { $match: { user: objId, date: { $lte: date } } },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const totalVariable = varAgg?.total || 0;

  let totalFixed = 0;
  subscriptions.forEach((sub) => {
    if (!sub.isActive) return;
    const start = new Date(sub.firstDetectedDate);
    if (start >= date) return;

    const monthsDiff =
      (date.getFullYear() - start.getFullYear()) * 12 +
      (date.getMonth() - start.getMonth());

    if (sub.frequency === "yearly") {
      const yearsDiff = Math.floor(monthsDiff / 12) + 1;
      totalFixed += yearsDiff * sub.amount;
    } else if (sub.frequency === "monthly") {
      totalFixed += (monthsDiff + 1) * sub.amount;
    } else if (sub.frequency === "bi-weekly") {
      totalFixed += (monthsDiff + 1) * 2 * sub.amount;
    } else if (sub.frequency === "weekly") {
      totalFixed += (monthsDiff + 1) * 4 * sub.amount;
    }
  });

  return totalIncome - totalVariable - totalFixed;
};

const linearRegression = (yValues) => {
  const n = yValues.length;
  if (n < 2) {
    return { slope: 0, intercept: yValues[0] || 0 };
  }
  let sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
  for (let i = 0; i < n; i++) {
    sumX += i;
    sumY += yValues[i];
    sumXY += i * yValues[i];
    sumXX += i * i;
  }
  const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX) || 0;
  const intercept = (sumY - slope * sumX) / n || 0;
  return { slope, intercept };
};

exports.getForecast = async (userId) => {
  const subscriptionsDocs = await Subscription.find({ user: userId }).lean();
  const subscriptions = subscriptionsDocs || [];

  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth(); // 0-indexed

  const historical = [];

  // Generate last 6 months (ending with current month)
  for (let i = 5; i >= 0; i--) {
    const tempDate = new Date(currentYear, currentMonth - i, 1);
    const year = tempDate.getFullYear();
    const monthIndex = tempDate.getMonth();

    const start = new Date(year, monthIndex, 1);
    const end = new Date(year, monthIndex + 1, 0, 23, 59, 59, 999);

    const [incAgg] = await Income.aggregate([
      {
        $match: {
          user: new mongoose.Types.ObjectId(userId),
          date: { $gte: start, $lte: end },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]);
    const monthlyInc = incAgg?.total || 0;

    const [varAgg] = await VariableExpense.aggregate([
      {
        $match: {
          user: new mongoose.Types.ObjectId(userId),
          date: { $gte: start, $lte: end },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]);
    const monthlyVar = varAgg?.total || 0;
    const monthlyFixed = calculateSubscriptionForMonth(subscriptions, year, monthIndex);

    const monthlyExp = monthlyVar + monthlyFixed;
    const netSavings = monthlyInc - monthlyExp;
    const endBalance = await computeBalanceAtDate(userId, subscriptions, end);

    const monthStr = `${year}-${String(monthIndex + 1).padStart(2, "0")}`;

    historical.push({
      month: monthStr,
      income: monthlyInc,
      expenses: monthlyExp,
      savings: netSavings,
      balance: endBalance,
    });
  }

  // Extract vectors for regression
  const incomes = historical.map((h) => h.income);
  const expenses = historical.map((h) => h.expenses);

  const incModel = linearRegression(incomes);
  const expModel = linearRegression(expenses);

  const predicted = [];
  let lastBalance = historical[historical.length - 1].balance;

  // Project next 6 months
  for (let i = 1; i <= 6; i++) {
    const tempDate = new Date(currentYear, currentMonth + i, 1);
    const year = tempDate.getFullYear();
    const monthIndex = tempDate.getMonth();

    const x = 5 + i; // Index in the regression line
    const projIncome = Math.max(0, incModel.slope * x + incModel.intercept);
    const projExpenses = Math.max(0, expModel.slope * x + expModel.intercept);
    const projSavings = projIncome - projExpenses;
    const projBalance = lastBalance + projSavings;
    lastBalance = projBalance;

    const monthStr = `${year}-${String(monthIndex + 1).padStart(2, "0")}`;

    predicted.push({
      month: monthStr,
      income: Math.round(projIncome * 100) / 100,
      expenses: Math.round(projExpenses * 100) / 100,
      savings: Math.round(projSavings * 100) / 100,
      balance: Math.round(projBalance * 100) / 100,
    });
  }

  return {
    historical,
    predicted,
  };
};
