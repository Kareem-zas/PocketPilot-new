const { GoogleGenerativeAI } = require("@google/generative-ai");

/**
 * Utility to rotate Gemini API keys evenly and safely.
 */
class GeminiRotator {
  constructor() {
    this.keys = [];
    
    // Load all keys from ENV
    const key1 = process.env.GEMINI_API_KEY_1;
    const key2 = process.env.GEMINI_API_KEY_2;
    const key3 = process.env.GEMINI_API_KEY_3;
    const key4 = process.env.GEMINI_API_KEY_4;

    if (key1) this.keys.push(key1);
    if (key2) this.keys.push(key2);
    if (key3) this.keys.push(key3);
    if (key4) this.keys.push(key4);

    if (this.keys.length === 0) {
      // Fallback
      this.keys.push("AIzaSyA-K636T426T0VvBjr-Q_XsZOwy1PzsT48");
    }

    this.currentIndex = 0;
  }

  /**
   * Returns a configured GoogleGenerativeAI instance using the next available API key (Round-Robin).
   */
  getAI() {
    // Pick the next key
    const selectedKey = this.keys[this.currentIndex];
    
    // Move to the next key, looping back to 0 if at the end
    this.currentIndex = (this.currentIndex + 1) % this.keys.length;

    console.log(`[AI Load Balancer] Using API Key Index: ${this.currentIndex}`);
    
    return new GoogleGenerativeAI(selectedKey);
  }
}

// Export a singleton instance
module.exports = new GeminiRotator();
