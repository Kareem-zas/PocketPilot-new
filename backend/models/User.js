const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const UserSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, "Please provide your full name"],
      trim: true,
    },
    email: {
      type: String,
      required: [true, "Please provide your email"],
      unique: true,
      lowercase: true,
      trim: true,
      match: [
        /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/,
        "Please provide a valid email",
      ],
    },
    phone: {
      type: String,
      required: [true, "Please provide your phone number"],
      unique: true,
      trim: true,
      validate: {
        validator: function (v) {
          // التحقق العام (يقبل أرقام دولية 10-15 خانة)
          return /^\+?[0-9]{10,15}$/.test(v);
          
          /* ملاحظة: إذا أردت إرجاعه للأرقام الأردنية فقط، استبدل السطر أعلاه بـ:
          return /^07[789]\d{7}$/.test(v);
          */
        },
        message: (props) => `${props.value} is not a valid phone number!`,
      },
    },
    password: {
      type: String,
      required: [true, "Please provide a password"],
      minlength: [8, "Password must be at least 8 characters"],
      select: false, 
    },
    openingBalance: {
      type: Number,
      default: 0,
    },
    pocketBalance: {
      type: Number,
      default: 0,
    },
    streakDays: {
      type: Number,
      default: 0,
    },
    unlockedBadges: {
      type: [String],
      default: [],
    },
    lastBudgetSuccessDate: {
      type: Date,
    },
    monthlyBudget: {
      type: Number,
      default: 1000,
    },
    emailVerified: { type: Boolean, default: false },
    otp: {
      code: String,
      expiresAt: Date
    }
  },
  { timestamps: true }
);

/* ===========================================
   1. تشفير كلمة المرور قبل الحفظ (Pre-save Hook)
   =========================================== */
UserSchema.pre("save", async function () {
  // إذا لم يتم تعديل الباسورد، تخطى التشفير
  if (!this.isModified("password")) return ;

  // التشفير بـ cost 12
  this.password = await bcrypt.hash(this.password, 12);
  
});

/* ===========================================
   2. دالة مقارنة الباسورد (Instance Method)
   =========================================== */
UserSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model("User", UserSchema);