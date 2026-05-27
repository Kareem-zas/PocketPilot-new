require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const mongoSanitize = require("express-mongo-sanitize");
const hpp = require("hpp");
const rateLimit = require("express-rate-limit");
const connectDB = require("./config/db");
const http = require("http");
const { Server } = require("socket.io");

// 
const AppError = require("./utils/AppError");
const globalErrorHandler = require("./controllers/errorController");

// Routes Imports
const authRoutes = require("./routes/authRoutes");
const incomeRoutes = require("./routes/incomeRoutes");
const fixedExpensesRoutes = require("./routes/fixedExpensesRoutes");
const variableExpensesRoutes = require("./routes/variableExpensesRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const reportRoutes = require("./routes/reportRoutes");
const goalsRoutes = require("./routes/goalsRoutes");
const pocketRoutes = require("./routes/pocketRoutes");
const subscriptionRoutes = require("./routes/subscriptionRoutes");
const forecastRoutes = require("./routes/forecastRoutes");
const gamificationRoutes = require("./routes/gamificationRoutes");
const cronService = require("./services/cronService");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: process.env.CLIENT_URL || (process.env.NODE_ENV === "production" ? false : "*"),
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"]
  }
});

io.on("connection", (socket) => {
  console.log("⚡ A user connected to WebSocket:", socket.id);

  socket.on("joinGoalRoom", (goalId) => {
    socket.join(`goal_${goalId}`);
    console.log(`Socket ${socket.id} joined room goal_${goalId}`);
  });

  socket.on("goalUpdated", (data) => {
    // Broadcast to others in the same room
    socket.to(`goal_${data.goalId}`).emit("goalUpdated", data);
  });

  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.id);
  });
});

// Make io accessible to our router if needed
app.set("io", io);

/* =========================
   Database Connection & Cron Jobs
========================= */
connectDB();
cronService.initCronJobs();

/* =========================
   Middlewares
========================= */
// 1. تفعيل Helmet لتعيين ترويسات أمان HTTP
app.use(helmet());

// 2. تفعيل CORS للسماح للفرونت إند بالوصول
app.use(
  cors({
    origin: process.env.CLIENT_URL || (process.env.NODE_ENV === "production" ? false : "*"),
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// 3. تحديد حد أقصى للطلبات لمنع Brute-Force و DoS (Global API Limiter)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 300, // حد أقصى 300 طلب لكل IP
  message: {
    status: "fail",
    message: "Too many requests from this IP, please try again after 15 minutes",
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use("/api", limiter);

// 4. تحديد حد أقصى لعمليات تسجيل الدخول وإنشاء الحسابات
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 20, // حد أقصى 20 محاولة لكل IP
  message: {
    status: "fail",
    message: "Too many login or register attempts, please try again after 15 minutes",
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use("/api/auth", authLimiter);

// 5. قراءة JSON من الطلبات مع تحديد الحد الأقصى لحجم الطلب لمنع هجمات Payload الكبيرة
app.use(express.json({ limit: "10kb" }));

// حل توافقية Express 5 مع مكتبة express-mongo-sanitize (لأن req.query للقراءة فقط بشكل افتراضي في Express 5)
app.use((req, res, next) => {
  Object.defineProperty(req, "query", {
    value: { ...req.query },
    writable: true,
    configurable: true,
    enumerable: true,
  });
  next();
});

// 6. حماية ضد هجمات NoSQL Injection عن طريق تنظيف المدخلات
app.use(mongoSanitize());

// 7. حماية ضد هجمات HTTP Parameter Pollution (HPP)
app.use(hpp());

/* =========================
   Mount Routes
========================= */
app.get("/", (req, res) => {
  res.status(200).json({
    status: "success",
    message: "Pocket Pilot API is online and healthy! 🚀",
  });
});

app.use("/api/auth", authRoutes);
app.use("/api/income", incomeRoutes);
app.use("/api/fixed-expenses", fixedExpensesRoutes);
app.use("/api/variable-expenses", variableExpensesRoutes);
app.use("/api/dashboard", dashboardRoutes); // 
app.use("/api/reports", reportRoutes);
app.use("/api/goals", goalsRoutes);
app.use("/api/pocket", pocketRoutes);
app.use("/api/subscriptions", subscriptionRoutes);
app.use("/api/forecast", forecastRoutes);
app.use("/api/gamification", gamificationRoutes);

/* =========================
   Error Handling
========================= */

// 1. التعامل مع الراوتات غير الموجودة (404)
// أي رابط يوصل لهون وما مسكه أي راوت فوق، يعتبر خطأ
app.all(/(.*)/, (req, res, next) => {
  next(new AppError(`Can't find ${req.originalUrl} on this server!`, 404));
});

// 2. Global Error Handler (المحطة الأخيرة للأخطاء)
// هذا الميدل وير هو اللي رح يستلم أي Error رميناه بـ next(new AppError)
app.use(globalErrorHandler);

/* =========================
   Server Start
========================= */
const PORT = process.env.PORT || 8000;

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});