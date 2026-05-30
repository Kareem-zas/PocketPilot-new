const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

/**
 * Sends a 6-digit OTP code to the user's email address.
 * @param {string} toEmail - Recipient's email address
 * @param {string} otp - 6-digit OTP code
 * @param {'verify' | 'reset'} type - Purpose of the OTP
 */
exports.sendOTP = async (toEmail, otp, type) => {
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    console.log(`\n======================================================`);
    console.log(`✉️  [MOCK EMAIL SENT TO ${toEmail}]`);
    console.log(`✉️  Type: ${type}`);
    console.log(`✉️  OTP CODE: ${otp}`);
    console.log(`⚠️  To send real emails, configure EMAIL_USER and EMAIL_PASS in .env`);
    console.log(`======================================================\n`);
    return;
  }

  const isVerify = type === "verify";
  const subject = isVerify
    ? "Verify Your Email - Pocket Pilot"
    : "Reset Your Password - Pocket Pilot";

  const actionText = isVerify
    ? "verify your email address"
    : "reset your password";

  const htmlContent = `
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 30px; border: 1px solid #e2e8f0; border-radius: 16px; background-color: #ffffff; color: #1e293b;">
      <div style="text-align: center; margin-bottom: 25px;">
        <h2 style="color: #1D9E75; margin: 0; font-size: 28px; font-weight: bold; letter-spacing: 0.5px;">Pocket Pilot</h2>
        <p style="color: #64748b; font-size: 14px; margin: 5px 0 0 0;">Your Personal Financial Cockpit</p>
      </div>
      <div style="padding: 30px; background-color: #f8fafc; border-radius: 12px; text-align: center; border: 1px solid #f1f5f9;">
        <p style="font-size: 16px; color: #334155; margin-top: 0; text-align: left;">Hello,</p>
        <p style="font-size: 16px; color: #334155; text-align: left; line-height: 1.5;">You requested to ${actionText}. Use the 6-digit verification code below to complete the process:</p>
        
        <div style="margin: 30px 0;">
          <span style="font-size: 38px; letter-spacing: 8px; color: #1D9E75; font-weight: bold; padding: 10px 20px; background: #e6f6f1; border-radius: 8px; display: inline-block;">${otp}</span>
        </div>
        
        <p style="font-size: 14px; color: #64748b; margin-bottom: 0; line-height: 1.5; text-align: left; border-top: 1px solid #e2e8f0; padding-top: 15px;">
          This OTP code is valid for <strong>10 minutes</strong>. If you did not make this request, you can safely ignore this email.
        </p>
      </div>
      <div style="text-align: center; margin-top: 25px; font-size: 12px; color: #94a3b8;">
        &copy; ${new Date().getFullYear()} Pocket Pilot. All rights reserved.
      </div>
    </div>
  `;

  const mailOptions = {
    from: `"Pocket Pilot" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: subject,
    html: htmlContent,
  };

  await transporter.sendMail(mailOptions);
};
