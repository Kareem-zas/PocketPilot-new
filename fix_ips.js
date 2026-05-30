const fs = require('fs');
const path = require('path');

const servicesDir = path.join(__dirname, 'pocket_pilot', 'lib', 'services');

function fixServices() {
  const files = fs.readdirSync(servicesDir).filter(f => f.endsWith('.dart'));
  let updatedCount = 0;

  for (const file of files) {
    const filePath = path.join(servicesDir, file);
    let content = fs.readFileSync(filePath, 'utf8');

    if (content.includes('192.168.1.17:8000/api')) {
      // Add import if missing
      if (!content.includes('package:pockect_pilot/config/app_config.dart')) {
        content = "import 'package:pockect_pilot/config/app_config.dart';\n" + content;
      }

      // Replace hardcoded URLs with string interpolation
      content = content.replace(/'http:\/\/192\.168\.1\.17:8000\/api(\/[^']*)?'/g, (match, p1) => {
        if (p1) {
          return `'\${AppConfig.baseUrl}${p1}'`;
        }
        return 'AppConfig.baseUrl';
      });

      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`Fixed ${file}`);
      updatedCount++;
    }
  }
  
  console.log(`Updated ${updatedCount} files.`);
}

fixServices();
