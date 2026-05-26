const mongoose = require("mongoose");
const Income = require("../models/income");
const FixedExpense = require("../models/fixedExpenses");
const VariableExpense = require("../models/variableExpenses");
const Goal = require("../models/Goal");

/* =====================================================
   Helper: حساب إجمالي المصاريف الثابتة لشهر بعينه
   monthIndex: 0 (Jan) to 11 (Dec)
===================================================== */
const calculateFixedForMonth = (fixedItems, year, monthIndex) => {
  const startOfMonth = new Date(year, monthIndex, 1);
  const endOfMonth = new Date(year, monthIndex + 1, 1);

  return fixedItems.reduce((total, item) => {
    if (!item.isActive) return total;
    // لم يبدأ بعد في هذا الشهر
    if (new Date(item.startDate) >= endOfMonth) return total;

    if (item.frequency === "yearly") {
      const start = new Date(item.startDate);
      // يُحسب فقط في شهر الاستحقاق كل سنة
      if (start.getMonth() !== monthIndex) return total;
    }
    return total + item.amount;
  }, 0);
};

/* =====================================================
   Helper: الرصيد التراكمي من أول يوم حتى اللحظة
   (كل الدخل) - (كل متغير) - (كل ثابت محسوب بأثر رجعي)
===================================================== */
const computeLifetimeBalance = async (userId, fixedItems) => {
  const objId = new mongoose.Types.ObjectId(userId);
  const now = new Date();

  // 1. مجموع كل الدخل
  const [incomeAgg] = await Income.aggregate([
    { $match: { user: objId } },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const totalIncome = incomeAgg?.total || 0;

  // 2. مجموع كل المصاريف المتغيرة (excluding goal deposits)
  const [varAgg] = await VariableExpense.aggregate([
    {
      $match: {
        user: objId,
        category: { $not: { $regex: /^savings$/i } },
        title: { $not: { $regex: /^goal deposit/i } },
      },
    },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const totalVariable = varAgg?.total || 0;

  // 3. مجموع المدخرات في الأهداف
  const [goalAgg] = await Goal.aggregate([
    { $match: { user: objId } },
    { $group: { _id: null, total: { $sum: "$savedAmount" } } },
  ]);
  const totalGoals = goalAgg?.total || 0;

  // 4. المصاريف الثابتة بأثر رجعي
  let totalFixed = 0;
  fixedItems.forEach((item) => {
    if (!item.isActive) return;
    const start = new Date(item.startDate);
    if (start >= now) return;

    const monthsDiff =
      (now.getFullYear() - start.getFullYear()) * 12 +
      (now.getMonth() - start.getMonth());

    if (item.frequency === "yearly") {
      const yearsDiff = Math.floor(monthsDiff / 12) + 1;
      totalFixed += yearsDiff * item.amount;
    } else {
      totalFixed += (monthsDiff + 1) * item.amount;
    }
  });

  return totalIncome - totalVariable - totalGoals - totalFixed;
};

/* =====================================================
   MAIN: getDashboardData
===================================================== */
exports.getDashboardData = async (userId, year, month, page = 1, pageSize = 10) => {
  const objId = new mongoose.Types.ObjectId(userId);
  const now = new Date();
  const currentYear = year || now.getFullYear();
  const currentMonth = month || now.getMonth() + 1;

  const startDate = new Date(currentYear, currentMonth - 1, 1);
  const endDate = new Date(currentYear, currentMonth, 1);

  // ── جلب البيانات بالتوازي لتحسين الأداء ──────────────────────────────
  const [
    incomeAgg,
    variableAgg,
    variableCatAgg,
    fixedDoc,
    recentIncomeDocs,
    recentVariableDocs,
  ] = await Promise.all([
    // دخل الشهر
    Income.aggregate([
      { $match: { user: objId, date: { $gte: startDate, $lt: endDate } } },
      {
        $group: {
          _id: null,
          total: { $sum: "$amount" },
          salary: {
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

    // مصاريف متغيرة الشهر (excluding goal deposits)
    VariableExpense.aggregate([
      {
        $match: {
          user: objId,
          date: { $gte: startDate, $lt: endDate },
          category: { $not: { $regex: /^savings$/i } },
          title: { $not: { $regex: /^goal deposit/i } },
        },
      },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),

    // تصنيف مصاريف متغيرة الشهر حسب category (excluding goal deposits)
    VariableExpense.aggregate([
      {
        $match: {
          user: objId,
          date: { $gte: startDate, $lt: endDate },
          category: { $not: { $regex: /^savings$/i } },
          title: { $not: { $regex: /^goal deposit/i } },
        },
      },
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

    // آخر إدخالات الدخل
    Income.find({ user: userId, date: { $gte: startDate, $lt: endDate } })
      .sort({ date: -1 })
      .limit(pageSize)
      .lean(),

    // آخر إدخالات المتغير (excluding goal deposits)
    VariableExpense.find({
      user: userId,
      date: { $gte: startDate, $lt: endDate },
      category: { $not: { $regex: /^savings$/i } },
      title: { $not: { $regex: /^goal deposit/i } },
    })
      .sort({ date: -1 })
      .limit(pageSize)
      .lean(),
  ]);

  // ── حسابات ─────────────────────────────────────────────────────────────
  const fixedItems = fixedDoc?.items || [];

  const monthlyIncome = incomeAgg[0]?.total || 0;
  const monthlySalary = incomeAgg[0]?.salary || 0;
  const monthlySideIncome = monthlyIncome - monthlySalary;

  const monthlyVariable = variableAgg[0]?.total || 0;
  const monthlyFixed = calculateFixedForMonth(fixedItems, currentYear, currentMonth - 1);
  const monthlyExpenses = monthlyFixed + monthlyVariable;
  const monthlyNet = monthlyIncome - monthlyExpenses;

  // ── الرصيد التراكمي ─────────────────────────────────────────────────
  const lifetimeBalance = await computeLifetimeBalance(userId, fixedItems);

  // ── آخر الحركات (الدخل + المتغير مدمجان ومرتبان) ───────────────────
  let recent = [
    ...recentIncomeDocs.map((i) => ({
      id: i._id,
      title: i.source,
      amount: i.amount,
      date: i.date,
      type: "income",
      category: "income",
    })),
    ...recentVariableDocs.map((v) => ({
      id: v._id,
      title: v.title,
      amount: v.amount,
      date: v.date,
      type: "expense",
      category: v.category || "other",
    })),
  ];
  recent.sort((a, b) => new Date(b.date) - new Date(a.date));
  recent = recent.slice(0, pageSize);

  // ── Active Fixed Items لهذا الشهر ───────────────────────────────────
  const activeFixedItems = fixedItems.filter((item) => {
    if (!item.isActive) return false;
    if (new Date(item.startDate) >= endDate) return false;
    if (item.frequency === "yearly") {
      return new Date(item.startDate).getMonth() === currentMonth - 1;
    }
    return true;
  });

  // ── الاستجابة النهائية ───────────────────────────────────────────────
  return {
    period: { year: currentYear, month: currentMonth },
    summary: {
      balance: lifetimeBalance,
      monthlyPerformance: monthlyNet,
      savingsRate: monthlyIncome > 0
        ? Math.round((monthlyNet / monthlyIncome) * 100)
        : 0,
      income: {
        total: monthlyIncome,
        salary: monthlySalary,
        sideIncome: monthlySideIncome,
        details: recentIncomeDocs,
      },
      expenses: {
        total: monthlyExpenses,
        fixed: {
          total: monthlyFixed,
          details: activeFixedItems,
        },
        variable: {
          total: monthlyVariable,
          byCategory: variableCatAgg.map((c) => ({
            category: c._id,
            total: c.total,
            count: c.count,
          })),
          details: recentVariableDocs,
        },
      },
    },
    recent,
  };
};