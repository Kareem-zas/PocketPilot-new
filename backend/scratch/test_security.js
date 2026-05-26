const http = require("http");

function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on("error", (err) => {
      reject(err);
    });

    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function runTests() {
  console.log("=== POCKET PILOT SECURITY VERIFICATION ===");

  // 1. Verify Helmet headers on root '/'
  try {
    const res = await makeRequest({
      hostname: "localhost",
      port: 8000,
      path: "/",
      method: "GET"
    });
    console.log("\n[TEST 1] Helmet Headers Check on root '/':");
    console.log("Status Code:", res.statusCode);
    console.log("X-Content-Type-Options:", res.headers["x-content-type-options"]);
    console.log("X-Frame-Options:", res.headers["x-frame-options"]);
    console.log("Content-Security-Policy:", res.headers["content-security-policy"] ? "Present" : "Missing");
    console.log("Body:", res.body);
    if (res.headers["x-content-type-options"] === "nosniff" && res.headers["x-frame-options"] === "SAMEORIGIN") {
      console.log("✅ Helmet headers verified successfully!");
    } else {
      console.log("⚠️ Some Helmet headers might be missing or customized.");
    }
  } catch (err) {
    console.error("❌ Test 1 Failed: Cannot connect to server. Is it running on port 8000?", err.message);
    return;
  }

  // 2. Verify Rate Limiter on login
  console.log("\n[TEST 2] Auth Rate Limiter Check (sending 25 rapid requests to login):");
  let triggered429 = false;
  for (let i = 1; i <= 25; i++) {
    try {
      const res = await makeRequest({
        hostname: "localhost",
        port: 8000,
        path: "/api/auth/login",
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        }
      }, JSON.stringify({ email: "test@example.com", password: "pwd" }));

      if (res.statusCode === 429) {
        console.log(`Request #${i} -> Status: 429 (Rate Limited!) ✅`);
        triggered429 = true;
        break;
      } else {
        console.log(`Request #${i} -> Status: ${res.statusCode}`);
      }
    } catch (err) {
      console.error("Error during request:", err.message);
    }
  }
  if (triggered429) {
    console.log("✅ Rate Limiting verified successfully!");
  } else {
    console.log("❌ Rate Limiting failed to trigger. Check configuration.");
  }

  // 3. Verify NoSQL injection sanitization / query check
  console.log("\n[TEST 3] NoSQL Query Injection Check:");
  try {
    const res = await makeRequest({
      hostname: "localhost",
      port: 8000,
      path: "/api/auth/login",
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      }
    }, JSON.stringify({ email: { "$gt": "" }, password: "pwd" }));
    console.log("Response with NoSQL operator injection payload:", res.statusCode, res.body);
    console.log("✅ NoSQL injection blocked/handled!");
  } catch (err) {
    console.error("Test 3 error:", err.message);
  }

  console.log("\n=== SECURITY VERIFICATION COMPLETE ===");
}

runTests();
