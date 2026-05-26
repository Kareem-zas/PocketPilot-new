const mongoose = require("mongoose");
const Income = require("../models/income");
const VariableExpense = require("../models/variableExpenses");
const FixedExpense = require("../models/fixedExpenses");

const calculateFixedForMonth = (fixedItems, year, monthIndex) => {
  const endOfMonth = new Date(year, monthIndex + 1, 1);

  return fixedItems.reduce((total, item) => {
    if (!item.isActive) return total;
    if (new Date(item.startDate) >= endOfMonth) return total;

    if (item.frequency === "yearly") {
      const start = new Date(item.startDate);
      if (start.getMonth() !== monthIndex) return total;
    }
    return total + item.amount;
  }, 0);
};

const computeBalanceAtDate = async (userId, fixedItems, date) => {
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
  fixedItems.forEach((item) => {
    if (!item.isActive) return;
    const start = new Date(item.startDate);
    if (start >= date) return;

    const monthsDiff =
      (date.getFullYear() - start.getFullYear()) * 12 +
      (date.getMonth() - start.getMonth());

    if (item.frequency === "yearly") {
      const yearsDiff = Math.floor(monthsDiff / 12) + 1;
      totalFixed += yearsDiff * item.amount;
    } else {
      totalFixed += (monthsDiff + 1) * item.amount;
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
  const fixedDoc = await FixedExpense.findOne({ user: userId }).lean();
  const fixedItems = fixedDoc?.items || [];

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
    const monthlyFixed = calculateFixedForMonth(fixedItems, year, monthIndex);

    const monthlyExp = monthlyVar + monthlyFixed;
    const netSavings = monthlyInc - monthlyExp;
    const endBalance = await computeBalanceAtDate(userId, fixedItems, end);

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
