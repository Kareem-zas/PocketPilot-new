const cron = require('node-cron');
const User = require('../models/User');
const subscriptionController = require('../controllers/subscriptionController');

exports.initCronJobs = () => {
  // Run every night at 2:00 AM
  cron.schedule('0 2 * * *', async () => {
    console.log('[Cron] Running subscription radar detection at 2 AM...');
    try {
      const users = await User.find({});
      for (const user of users) {
        await subscriptionController.runDetection(user._id);
      }
      console.log('[Cron] Subscription radar detection completed.');
    } catch (error) {
      console.error('[Cron] Error running subscription radar:', error);
    }
  });
  console.log('[Cron] Subscription radar cron job scheduled (Runs daily at 2:00 AM).');
};
