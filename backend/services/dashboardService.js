const mongoose = require("mongoose");
const Income = require("../models/income");
const Subscription = require("../models/Subscription");
const VariableExpense = require("../models/variableExpenses");
const Goal = require("../models/Goal");

/* =====================================================
   Helper: حساب إجمالي المصاريف الثابتة لشهر بعينه
   monthIndex: 0 (Jan) to 11 (Dec)
===================================================== */
const calculateSubscriptionForMonth = (subscriptions, year, monthIndex) => {
  const startOfMonth = new Date(year, monthIndex, 1);
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

/* =====================================================
   Helper: الرصيد التراكمي من أول يوم حتى اللحظة
   (كل الدخل) - (كل متغير) - (كل ثابت محسوب بأثر رجعي)
===================================================== */
const computeLifetimeBalance = async (userId, subscriptions) => {
  const objId = new mongoose.Types.ObjectId(userId);
  const now = new Date();

  // 1. مجموع الدخل غير المتكرر (one-time incomes)
  const [onetimeAgg] = await Income.aggregate([
    { $match: { user: objId, isRecurring: false } },
    { $group: { _id: null, total: { $sum: "$amount" } } },
  ]);
  const totalOneTime = onetimeAgg?.total || 0;

  // 2. حساب الدخل المتكرر — كل دخل متكرر نحسب عدد دورات دفعه حتى الآن
  const recurringIncomes = await Income.find({
    user: objId,
    isRecurring: true,
  }).lean();

  let totalRecurring = 0;
  for (const inc of recurringIncomes) {
    if (!inc.isActive && (!inc.pausedMonths || inc.pausedMonths.length === 0)) {
      // Fully deactivated and never had any payments — skip
      // (if it was active before and then deactivated, we count up to deactivation)
      // For simplicity: if isActive=false, we still count all cycles that happened
      // before any future months (the user deactivated it going forward)
    }

    const startDate = new Date(inc.date);
    const pausedSet = new Set(
      (inc.pausedMonths || []).map((p) => `${p.year}-${p.month}`)
    );

    let cycles = 0;

    if (inc.frequency === "monthly") {
      // Count each month from startDate to now
      let cursor = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
      const nowMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      while (cursor <= nowMonth) {
        const key = `${cursor.getFullYear()}-${cursor.getMonth() + 1}`;
        if (!pausedSet.has(key)) {
          cycles++;
        }
        cursor.setMonth(cursor.getMonth() + 1);
      }
    } else if (inc.frequency === "quarterly") {
      let cursor = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
      while (cursor <= now) {
        const key = `${cursor.getFullYear()}-${cursor.getMonth() + 1}`;
        if (!pausedSet.has(key)) cycles++;
        cursor.setMonth(cursor.getMonth() + 3);
      }
    } else if (inc.frequency === "bi-annual") {
      let cursor = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
      while (cursor <= now) {
        const key = `${cursor.getFullYear()}-${cursor.getMonth() + 1}`;
        if (!pausedSet.has(key)) cycles++;
        cursor.setMonth(cursor.getMonth() + 6);
      }
    } else if (inc.frequency === "yearly") {
      let cursor = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
      while (cursor <= now) {
        const key = `${cursor.getFullYear()}-${cursor.getMonth() + 1}`;
        if (!pausedSet.has(key)) cycles++;
        cursor.setFullYear(cursor.getFullYear() + 1);
      }
    }

    totalRecurring += cycles * inc.amount;
  }

  const totalIncome = totalOneTime + totalRecurring;


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
  subscriptions.forEach((sub) => {
    if (!sub.isActive) return;
    const start = new Date(sub.firstDetectedDate);
    if (start >= now) return;

    const monthsDiff =
      (now.getFullYear() - start.getFullYear()) * 12 +
      (now.getMonth() - start.getMonth());

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
    subscriptionsDocs,
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

    // الاشتراكات الثابتة
    Subscription.find({ user: userId }).lean(),

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
  const subscriptions = subscriptionsDocs || [];

  const monthlyIncome = incomeAgg[0]?.total || 0;
  const monthlySalary = incomeAgg[0]?.salary || 0;
  const monthlySideIncome = monthlyIncome - monthlySalary;

  const monthlyVariable = variableAgg[0]?.total || 0;
  const monthlyFixed = calculateSubscriptionForMonth(subscriptions, currentYear, currentMonth - 1);
  const monthlyExpenses = monthlyFixed + monthlyVariable;
  const monthlyNet = monthlyIncome - monthlyExpenses;

  // ── الرصيد التراكمي ─────────────────────────────────────────────────
  const lifetimeBalance = await computeLifetimeBalance(userId, subscriptions);

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

  // ── Active Subscription Items لهذا الشهر ───────────────────────────────────
  const activeSubscriptions = subscriptions.filter((sub) => {
    if (!sub.isActive) return false;
    if (new Date(sub.firstDetectedDate) >= endDate) return false;
    if (sub.frequency === "yearly") {
      return new Date(sub.firstDetectedDate).getMonth() === currentMonth - 1;
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
          details: activeSubscriptions,
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