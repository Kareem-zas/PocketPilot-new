// utils/catchAsync.js
module.exports = (fn) => {
  return (req, res, next) => {
    // أي خطأ يحدث داخل الدالة، أرسله للـ Global Error Handler تلقائياً
    fn(req, res, next).catch(next);
  };
};