const jwt = require("jsonwebtoken");

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  if (process.env.NODE_ENV === "production") {
    throw new Error("FATAL: JWT_SECRET environment variable is missing in production!");
  } else {
    console.warn("⚠️ WARNING: JWT_SECRET is not set. Using insecure default 'your_secret_key' for development.");
  }
}

const finalSecret = JWT_SECRET || "your_secret_key";

exports.auth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "No token provided" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, finalSecret);
    req.userId = decoded.id; // نخزن userId بالـ request
    next();
  } catch (err) {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
};
