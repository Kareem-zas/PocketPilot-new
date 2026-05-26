const mongoose = require("mongoose");
const Income = require("../models/income");
const FixedExpense = require("../models/fixedExpenses");
const VariableExpense = require("../models/variableExpenses");

/* =====================================================
   Helper: حساب المصاريف الثابتة لشهر بعينه
   monthIndex: 0 (Jan) → 11 (Dec)
===================================================== */
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

/* =====================================================
   1. Monthly Report
===================================================== */
exports.getMonthlyData = async (userId, year, month) => {
  const objId = new mongoose.Types.ObjectId(userId);
  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 1);

  const [incomeAgg, variableAgg, variableByCat, fixedDoc, incomeDetails, variableDetails] =
    await Promise.all([
      // مجموع الدخل
      Income.aggregate([
        { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
        {
          $group: {
            _id: null,
            totalIncome: { $sum: "$amount" },
            totalSalary: {
              $sum: {
                $cond: [
                  { $regexMatch: { input: { $toLower: "$source" }, regex: /salary/ } },
                  "$amount",
                  0,
                ],
              },
            },
          },
        },
      ]),

      // مجموع المتغير
      VariableExpense.aggregate([
        { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),

      // تصنيف المتغير حسب category (للرسوم البيانية)
      VariableExpense.aggregate([
        { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
        {
          $group: {
            _id: { $ifNull: ["$category", "other"] },
            total: { $sum: "$amount" },
            count: { $sum: 1 },
          },
        },
        { $sort: { total: -1 } },
      ]),

      // المصاريف الثابتة
      FixedExpense.findOne({ user: userId }).lean(),

      // تفاصيل الدخل
      Income.find({ user: objId, date: { $gte: startDate, $lt: endDate } })
        .sort({ date: -1 })
        .lean(),

      // تفاصيل المتغير
      VariableExpense.find({ user: objId, date: { $gte: startDate, $lt: endDate } })
        .sort({ date: -1 })
        .lean(),
    ]);

  const fixedItems = fixedDoc?.items || [];
  const totalIncome = incomeAgg[0]?.totalIncome || 0;
  const totalSalary = incomeAgg[0]?.totalSalary || 0;
  const totalSideIncome = totalIncome - totalSalary;
  const totalVariableExpenses = variableAgg[0]?.total || 0;
  const totalFixedExpenses = calculateFixedForMonth(fixedItems, year, month - 1);
  const totalExpenses = totalFixedExpenses + totalVariableExpenses;

  return {
    year,
    month,
    totalIncome,
    totalSalary,
    totalSideIncome,
    totalFixedExpenses,
    totalVariableExpenses,
    totalExpenses,
    balance: totalIncome - totalExpenses,
    savingsRate: totalIncome > 0
      ? Math.round(((totalIncome - totalExpenses) / totalIncome) * 100)
      : 0,
    expensesByCategory: variableByCat.map((c) => ({
      category: c._id,
      total: c.total,
      count: c.count,
      percentage: totalVariableExpenses > 0
        ? Math.round((c.total / totalVariableExpenses) * 100)
        : 0,
    })),
    details: {
      income: incomeDetails,
      variableExpenses: variableDetails,
    },
  };
};

/* =====================================================
   2. Yearly Report (Summary)
===================================================== */
exports.getYearlyData = async (userId, year) => {
  const objId = new mongoose.Types.ObjectId(userId);
  const startDate = new Date(year, 0, 1);
  const endDate = new Date(Number(year) + 1, 0, 1);

  const [incomeAgg, variableAgg, variableByCat, fixedDoc] = await Promise.all([
    Income.aggregate([
      { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
      {
        $group: {
          _id: null,
          totalIncome: { $sum: "$amount" },
          totalSalary: {
            $sum: {
              $cond: [
                { $regexMatch: { input: { $toLower: "$source" }, regex: /salary/ } },
                "$amount",
                0,
              ],
            },
          },
        },
      },
    ]),

    VariableExpense.aggregate([
      { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),

    // تصنيف المتغير حسب category للسنة كاملة
    VariableExpense.aggregate([
      { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
      {
        $group: {
          _id: { $ifNull: ["$category", "other"] },
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
      { $sort: { total: -1 } },
    ]),

    FixedExpense.findOne({ user: userId }).lean(),
  ]);

  const fixedItems = fixedDoc?.items || [];

  // حساب الثابت لكل الـ 12 شهر
  let totalFixedExpenses = 0;
  for (let i = 0; i < 12; i++) {
    totalFixedExpenses += calculateFixedForMonth(fixedItems, year, i);
  }

  const totalIncome = incomeAgg[0]?.totalIncome || 0;
  const totalSalary = incomeAgg[0]?.totalSalary || 0;
  const totalSideIncome = totalIncome - totalSalary;
  const totalVariableExpenses = variableAgg[0]?.total || 0;
  const totalExpenses = totalFixedExpenses + totalVariableExpenses;

  return {
    year,
    totalIncome,
    totalSalary,
    totalSideIncome,
    totalFixedExpenses,
    totalVariableExpenses,
    totalExpenses,
    balance: totalIncome - totalExpenses,
    savingsRate: totalIncome > 0
      ? Math.round(((totalIncome - totalExpenses) / totalIncome) * 100)
      : 0,
    expensesByCategory: variableByCat.map((c) => ({
      category: c._id,
      total: c.total,
      count: c.count,
      percentage: totalVariableExpenses > 0
        ? Math.round((c.total / totalVariableExpenses) * 100)
        : 0,
    })),
  };
};

/* =====================================================
   3. Monthly Breakdown (شهر بشهر — للرسوم البيانية)
===================================================== */
exports.getBreakdownData = async (userId, year) => {
  const objId = new mongoose.Types.ObjectId(userId);
  const startDate = new Date(year, 0, 1);
  const endDate = new Date(Number(year) + 1, 0, 1);

  const [incomeByMonth, variableByMonth, fixedDoc] = await Promise.all([
    Income.aggregate([
      { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
      {
        $group: {
          _id: { month: { $month: "$date" } },
          totalIncome: { $sum: "$amount" },
          totalSalary: {
            $sum: {
              $cond: [
                { $regexMatch: { input: { $toLower: "$source" }, regex: /salary/ } },
                "$amount",
                0,
              ],
            },
          },
        },
      },
    ]),

    VariableExpense.aggregate([
      { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
      {
        $group: {
          _id: {
            month: { $month: "$date" },
            category: { $ifNull: ["$category", "other"] },
          },
          total: { $sum: "$amount" },
        },
      },
    ]),

    FixedExpense.findOne({ user: userId }).lean(),
  ]);

  const fixedItems = fixedDoc?.items || [];

  // بناء مصفوفة الـ 12 شهر
  const months = Array.from({ length: 12 }, (_, i) => {
    const monthIndex = i + 1; // 1–12

    const incomeData = incomeByMonth.find((m) => m._id.month === monthIndex);
    const income = incomeData?.totalIncome || 0;
    const salary = incomeData?.totalSalary || 0;

    // المتغير: كل التصنيفات لهذا الشهر
    const monthVarEntries = variableByMonth.filter((m) => m._id.month === monthIndex);
    const variable = monthVarEntries.reduce((sum, e) => sum + e.total, 0);

    const fixed = calculateFixedForMonth(fixedItems, year, i);
    const totalExpenses = variable + fixed;

    return {
      month: monthIndex,
      totalIncome: income,
      totalSalary: salary,
      totalSideIncome: income - salary,
      totalFixed: fixed,
      totalVariable: variable,
      totalExpenses,
      balance: income - totalExpenses,
      savingsRate: income > 0 ? Math.round(((income - totalExpenses) / income) * 100) : 0,
      // تصنيف المصاريف المتغيرة لهذا الشهر
      variableByCategory: monthVarEntries.map((e) => ({
        category: e._id.category,
        total: e.total,
        percentage: variable > 0 ? Math.round((e.total / variable) * 100) : 0,
      })),
    };
  });

  // إحصائيات السنة الكاملة من المصفوفة
  const yearly = months.reduce(
    (acc, m) => ({
      totalIncome: acc.totalIncome + m.totalIncome,
      totalExpenses: acc.totalExpenses + m.totalExpenses,
      totalFixed: acc.totalFixed + m.totalFixed,
      totalVariable: acc.totalVariable + m.totalVariable,
    }),
    { totalIncome: 0, totalExpenses: 0, totalFixed: 0, totalVariable: 0 }
  );

  return {
    year,
    yearly: {
      ...yearly,
      balance: yearly.totalIncome - yearly.totalExpenses,
      savingsRate: yearly.totalIncome > 0
        ? Math.round(((yearly.totalIncome - yearly.totalExpenses) / yearly.totalIncome) * 100)
        : 0,
    },
    months,
  };
};