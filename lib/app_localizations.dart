import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const Map<String, Map<String, String>> screenTextTranslations = {
    'en': {
      'Identity Verification': 'Identity Verification',
      'Verify Email': 'Verify Email',
      'Enter OTP': 'Enter OTP',
      'Ask Retail Mind': 'Ask Retail Mind',
      'Daily Closing': 'Daily Closing',
      "Today's Total Revenue": "Today's Total Revenue",
      'Online Orders': 'Online Orders',
      'More': 'More',
      'Your shop workspace': 'Your shop workspace',
      'Manage your shop': 'Manage your shop',
      'Offline-first workspace': 'Offline-first workspace',
      'Retail Growth': 'Retail Growth',
      'Retail Growth Suite': 'Retail Growth Suite',
      'Khata & Udhar': 'Khata & Udhar',
      'Khata & Pending Udhar': 'Khata & Pending Udhar',
      'Invoice Analytics': 'Invoice Analytics',
      'Export Summary': 'Export Summary',
      'Paid Invoices': 'Paid Invoices',
      'Bank Statement Parser': 'Bank Statement Parser',
      'Online Store': 'Online Store',
      'Online Store Manager': 'Online Store Manager',
      'Enable Online Store': 'Enable Online Store',
      'Delivery & Pickup': 'Delivery & Pickup',
      'Order Constraints': 'Order Constraints',
      'Create shop coupon': 'Create shop coupon',
      'Fixed amount discount': 'Fixed amount discount',
      'Top Customers by Uncleared Amount': 'Top Customers by Uncleared Amount',
      'Current Pending Balance:': 'Current Pending Balance:',
      'Refresh invoices': 'Refresh invoices',
      'Search customer, phone or invoice...':
          'Search customer, phone or invoice...',
      'Items Requested:': 'Items Requested:',
      'No Staff Accounts': 'No Staff Accounts',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.',
      'Ask Retail Mind about payments': 'Ask Retail Mind about payments',
      'Paid invoices will appear after cloud sync completes.':
          'Paid invoices will appear after cloud sync completes.',
      'Newest first': 'Newest first',
      'Oldest first': 'Oldest first',
      'Highest amount': 'Highest amount',
      'Lowest amount': 'Lowest amount',
      'Are you the Owner or a Staff Member?':
          'Are you the Owner or a Staff Member?',
      'Listen to this page': 'Listen to this page',
      'Pending Udhar': 'Pending Udhar',
      'Ask a business question': 'Ask a business question',
      'Ask your shop anything': 'Ask your shop anything',
      'Ask about sales, revenue, customers, stock…':
          'Ask about sales, revenue, customers, stock…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'Ask about stock, profit, returns, delivery or online orders…',
      'Actual Cash Being Handed Over': 'Actual Cash Being Handed Over',
      'Opening Cash Balance': 'Opening Cash Balance',
      'Closing Cash Balance': 'Closing Cash Balance',
      'CONFIRM CLOSING': 'CONFIRM CLOSING',
      'CLOSE DAY & PREPARE REPORT': 'CLOSE DAY & PREPARE REPORT',
      'Please enter the actual cash being handed over':
          'Please enter the actual cash being handed over',
      'Accept Order': 'Accept Order',
      'Mark as Dispatched': 'Mark as Dispatched',
      'Mark as Delivered': 'Mark as Delivered',
      'Coupon code': 'Coupon code',
      'Discount type': 'Discount type',
      'Minimum order amount (₹)': 'Minimum order amount (₹)',
      'Maximum redemptions (optional)': 'Maximum redemptions (optional)',
      'Record Payment': 'Record Payment',
      'TOTAL OUTSTANDING UDHAR': 'TOTAL OUTSTANDING UDHAR',
      'Payment Breakdown': 'Payment Breakdown',
      'Statement Summary': 'Statement Summary',
      'Net flow for this search': 'Net flow for this search',
      'Online Payments (UPI/Cards)': 'Online Payments (UPI/Cards)',
      'Cash on Delivery (COD)': 'Cash on Delivery (COD)',
      'Search invoice #, customer, phone...':
          'Search invoice #, customer, phone...',
      'Your payment breakdown will appear when invoices are available.':
          'Your payment breakdown will appear when invoices are available.',
      'Logout?': 'Logout?',
      'Confirm Logout': 'Confirm Logout',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'Are you sure you want to logout? Your synced data will safely return when you log back in.',
      'Are you sure you want to log out?': 'Are you sure you want to log out?',
      'Cancel': 'Cancel',
      'CANCEL': 'CANCEL',
      'Logout': 'Logout',
      'LOGOUT': 'LOGOUT',
      'Logging out...': 'Logging out...',
    },
    'te': {
      'Identity Verification': 'గుర్తింపు ధృవీకరణ',
      'Verify Email': 'ఈమెయిల్‌ను ధృవీకరించండి',
      'Enter OTP': 'OTP నమోదు చేయండి',
      'Ask Retail Mind': 'Retail Mind‌ను అడగండి',
      'Daily Closing': 'రోజువారీ ముగింపు',
      "Today's Total Revenue": 'ఈరోజు మొత్తం ఆదాయం',
      'Online Orders': 'ఆన్‌లైన్ ఆర్డర్‌లు',
      'More': 'మరిన్ని',
      'Your shop workspace': 'మీ దుకాణం పని ప్రదేశం',
      'Manage your shop': 'మీ దుకాణాన్ని నిర్వహించండి',
      'Offline-first workspace': 'ఆఫ్‌లైన్‌లోనూ పనిచేసే కార్యస్థలం',
      'Retail Growth': 'రిటైల్ వృద్ధి',
      'Retail Growth Suite': 'రిటైల్ వృద్ధి సాధనాలు',
      'Khata & Udhar': 'ఖాతా & ఉధార్',
      'Khata & Pending Udhar': 'ఖాతా & బకాయి ఉధార్',
      'Invoice Analytics': 'ఇన్వాయిస్ విశ్లేషణ',
      'Export Summary': 'సారాంశాన్ని ఎగుమతి చేయండి',
      'Paid Invoices': 'చెల్లించిన ఇన్వాయిస్‌లు',
      'Bank Statement Parser': 'బ్యాంక్ స్టేట్‌మెంట్ విశ్లేషణ',
      'Online Store': 'ఆన్‌లైన్ దుకాణం',
      'Online Store Manager': 'ఆన్‌లైన్ దుకాణ నిర్వహణ',
      'Enable Online Store': 'ఆన్‌లైన్ దుకాణాన్ని ప్రారంభించండి',
      'Delivery & Pickup': 'డెలివరీ & పికప్',
      'Order Constraints': 'ఆర్డర్ పరిమితులు',
      'Create shop coupon': 'దుకాణ కూపన్ సృష్టించండి',
      'Fixed amount discount': 'స్థిర మొత్తపు తగ్గింపు',
      'Top Customers by Uncleared Amount':
          'చెల్లించని మొత్తం ఆధారంగా అగ్ర కస్టమర్లు',
      'Current Pending Balance:': 'ప్రస్తుత బకాయి నిల్వ:',
      'Refresh invoices': 'ఇన్వాయిస్‌లను రిఫ్రెష్ చేయండి',
      'Search customer, phone or invoice...':
          'కస్టమర్, ఫోన్ లేదా ఇన్వాయిస్ కోసం వెతకండి...',
      'Items Requested:': 'అభ్యర్థించిన వస్తువులు:',
      'No Staff Accounts': 'సిబ్బంది ఖాతాలు లేవు',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI అంతర్దృష్టులు, స్మార్ట్ నిల్వ, శాఖలు, డెలివరీ, కస్టమర్ లాయల్టీ, ప్రమోషన్లు మరియు భద్రత.',
      'Ask Retail Mind about payments':
          'చెల్లింపుల గురించి Retail Mind‌ను అడగండి',
      'Paid invoices will appear after cloud sync completes.':
          'క్లౌడ్ సమకాలీకరణ పూర్తయ్యాక చెల్లించిన ఇన్వాయిస్‌లు కనిపిస్తాయి.',
      'Newest first': 'కొత్తవి ముందు',
      'Oldest first': 'పాతవి ముందు',
      'Highest amount': 'అత్యధిక మొత్తం',
      'Lowest amount': 'అత్యల్ప మొత్తం',
      'Are you the Owner or a Staff Member?':
          'మీరు యజమానా లేదా సిబ్బంది సభ్యులా?',
      'Listen to this page': 'ఈ పేజీని వినండి',
      'Pending Udhar': 'బకాయి ఉధార్',
      'Ask a business question': 'వ్యాపారం గురించి ప్రశ్న అడగండి',
      'Ask your shop anything': 'మీ దుకాణం గురించి ఏదైనా అడగండి',
      'Ask about sales, revenue, customers, stock…':
          'అమ్మకాలు, ఆదాయం, కస్టమర్లు, నిల్వ గురించి అడగండి…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'నిల్వ, లాభం, రిటర్నులు, డెలివరీ లేదా ఆన్‌లైన్ ఆర్డర్‌ల గురించి అడగండి…',
      'Actual Cash Being Handed Over': 'ఇప్పుడు అప్పగిస్తున్న నగదు',
      'Opening Cash Balance': 'ప్రారంభ నగదు నిల్వ',
      'Closing Cash Balance': 'ముగింపు నగదు నిల్వ',
      'CONFIRM CLOSING': 'ముగింపును నిర్ధారించండి',
      'CLOSE DAY & PREPARE REPORT': 'రోజును ముగించి నివేదిక సిద్ధం చేయండి',
      'Please enter the actual cash being handed over':
          'అప్పగిస్తున్న వాస్తవ నగదు మొత్తాన్ని నమోదు చేయండి',
      'Accept Order': 'ఆర్డర్‌ను అంగీకరించండి',
      'Mark as Dispatched': 'పంపినట్లు గుర్తించండి',
      'Mark as Delivered': 'డెలివరీ చేసినట్లు గుర్తించండి',
      'Coupon code': 'కూపన్ కోడ్',
      'Discount type': 'తగ్గింపు రకం',
      'Minimum order amount (₹)': 'కనిష్ట ఆర్డర్ మొత్తం (₹)',
      'Maximum redemptions (optional)': 'గరిష్ఠ వినియోగాలు (ఐచ్ఛికం)',
      'Record Payment': 'చెల్లింపును నమోదు చేయండి',
      'TOTAL OUTSTANDING UDHAR': 'మొత్తం బకాయి ఉధార్',
      'Payment Breakdown': 'చెల్లింపు వివరాలు',
      'Statement Summary': 'స్టేట్‌మెంట్ సారాంశం',
      'Net flow for this search': 'ఈ శోధనకు నికర నగదు ప్రవాహం',
      'Online Payments (UPI/Cards)': 'ఆన్‌లైన్ చెల్లింపులు (UPI/కార్డులు)',
      'Cash on Delivery (COD)': 'డెలివరీ సమయంలో నగదు (COD)',
      'Search invoice #, customer, phone...':
          'ఇన్వాయిస్ నంబర్, కస్టమర్ లేదా ఫోన్ వెతకండి...',
      'Your payment breakdown will appear when invoices are available.':
          'ఇన్వాయిస్‌లు అందుబాటులోకి వచ్చినప్పుడు చెల్లింపు వివరాలు కనిపిస్తాయి.',
      'Logout?': 'లాగ్ అవుట్ చేయాలా?',
      'Confirm Logout': 'లాగ్ అవుట్ నిర్ధారించండి',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'మీరు లాగ్ అవుట్ చేయాలనుకుంటున్నారా? మళ్లీ లాగిన్ అయినప్పుడు సమకాలీకరించిన మీ డేటా సురక్షితంగా తిరిగి వస్తుంది.',
      'Are you sure you want to log out?':
          'మీరు ఖచ్చితంగా లాగ్ అవుట్ చేయాలనుకుంటున్నారా?',
      'Cancel': 'రద్దు చేయండి',
      'CANCEL': 'రద్దు చేయండి',
      'Logout': 'లాగ్ అవుట్',
      'LOGOUT': 'లాగ్ అవుట్',
      'Logging out...': 'లాగ్ అవుట్ అవుతోంది...',
    },
    'hi': {
      'Identity Verification': 'पहचान सत्यापन',
      'Verify Email': 'ईमेल सत्यापित करें',
      'Enter OTP': 'OTP दर्ज करें',
      'Ask Retail Mind': 'Retail Mind से पूछें',
      'Daily Closing': 'दैनिक समापन',
      "Today's Total Revenue": 'आज का कुल राजस्व',
      'Online Orders': 'ऑनलाइन ऑर्डर',
      'More': 'और',
      'Your shop workspace': 'आपकी दुकान का कार्यक्षेत्र',
      'Manage your shop': 'अपनी दुकान प्रबंधित करें',
      'Offline-first workspace': 'ऑफलाइन में भी काम करने वाला कार्यक्षेत्र',
      'Retail Growth': 'रिटेल विकास',
      'Retail Growth Suite': 'रिटेल विकास टूल',
      'Khata & Udhar': 'खाता और उधार',
      'Khata & Pending Udhar': 'खाता और बकाया उधार',
      'Invoice Analytics': 'इनवॉइस विश्लेषण',
      'Export Summary': 'सारांश निर्यात करें',
      'Paid Invoices': 'भुगतान किए गए इनवॉइस',
      'Bank Statement Parser': 'बैंक स्टेटमेंट विश्लेषक',
      'Online Store': 'ऑनलाइन स्टोर',
      'Online Store Manager': 'ऑनलाइन स्टोर प्रबंधक',
      'Enable Online Store': 'ऑनलाइन स्टोर चालू करें',
      'Delivery & Pickup': 'डिलीवरी और पिकअप',
      'Order Constraints': 'ऑर्डर सीमाएँ',
      'Create shop coupon': 'दुकान का कूपन बनाएँ',
      'Fixed amount discount': 'निश्चित राशि की छूट',
      'Top Customers by Uncleared Amount': 'बकाया राशि के अनुसार प्रमुख ग्राहक',
      'Current Pending Balance:': 'वर्तमान बकाया राशि:',
      'Refresh invoices': 'इनवॉइस रीफ़्रेश करें',
      'Search customer, phone or invoice...': 'ग्राहक, फ़ोन या इनवॉइस खोजें...',
      'Items Requested:': 'माँगी गई वस्तुएँ:',
      'No Staff Accounts': 'कोई कर्मचारी खाता नहीं',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI जानकारी, स्मार्ट इन्वेंटरी, शाखाएँ, डिलीवरी, ग्राहक निष्ठा, प्रचार और सुरक्षा।',
      'Ask Retail Mind about payments':
          'भुगतान के बारे में Retail Mind से पूछें',
      'Paid invoices will appear after cloud sync completes.':
          'क्लाउड सिंक पूरा होने के बाद भुगतान किए गए इनवॉइस दिखाई देंगे।',
      'Newest first': 'नवीनतम पहले',
      'Oldest first': 'सबसे पुराने पहले',
      'Highest amount': 'सबसे अधिक राशि',
      'Lowest amount': 'सबसे कम राशि',
      'Are you the Owner or a Staff Member?': 'क्या आप मालिक हैं या कर्मचारी?',
      'Listen to this page': 'इस पेज को सुनें',
      'Pending Udhar': 'बकाया उधार',
      'Ask a business question': 'व्यापार के बारे में प्रश्न पूछें',
      'Ask your shop anything': 'अपनी दुकान के बारे में कुछ भी पूछें',
      'Ask about sales, revenue, customers, stock…':
          'बिक्री, आय, ग्राहकों और स्टॉक के बारे में पूछें…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'स्टॉक, लाभ, रिटर्न, डिलीवरी या ऑनलाइन ऑर्डर के बारे में पूछें…',
      'Actual Cash Being Handed Over': 'सौंपे जा रहे वास्तविक नकद',
      'Opening Cash Balance': 'शुरुआती नकद शेष',
      'Closing Cash Balance': 'समापन नकद शेष',
      'CONFIRM CLOSING': 'समापन की पुष्टि करें',
      'CLOSE DAY & PREPARE REPORT': 'दिन बंद करें और रिपोर्ट तैयार करें',
      'Please enter the actual cash being handed over':
          'सौंपे जा रहे वास्तविक नकद की राशि दर्ज करें',
      'Accept Order': 'ऑर्डर स्वीकार करें',
      'Mark as Dispatched': 'भेजा गया चिह्नित करें',
      'Mark as Delivered': 'डिलीवर किया गया चिह्नित करें',
      'Coupon code': 'कूपन कोड',
      'Discount type': 'छूट का प्रकार',
      'Minimum order amount (₹)': 'न्यूनतम ऑर्डर राशि (₹)',
      'Maximum redemptions (optional)': 'अधिकतम उपयोग (वैकल्पिक)',
      'Record Payment': 'भुगतान दर्ज करें',
      'TOTAL OUTSTANDING UDHAR': 'कुल बकाया उधार',
      'Payment Breakdown': 'भुगतान विवरण',
      'Statement Summary': 'स्टेटमेंट सारांश',
      'Net flow for this search': 'इस खोज के लिए शुद्ध प्रवाह',
      'Online Payments (UPI/Cards)': 'ऑनलाइन भुगतान (UPI/कार्ड)',
      'Cash on Delivery (COD)': 'डिलीवरी पर नकद (COD)',
      'Search invoice #, customer, phone...':
          'इनवॉइस नंबर, ग्राहक या फ़ोन खोजें...',
      'Your payment breakdown will appear when invoices are available.':
          'इनवॉइस उपलब्ध होने पर भुगतान विवरण दिखाई देगा।',
      'Logout?': 'लॉग आउट करें?',
      'Confirm Logout': 'लॉग आउट की पुष्टि करें',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'क्या आप लॉग आउट करना चाहते हैं? दोबारा लॉग इन करने पर आपका सिंक किया गया डेटा सुरक्षित रूप से वापस आ जाएगा।',
      'Are you sure you want to log out?': 'क्या आप लॉग आउट करना चाहते हैं?',
      'Cancel': 'रद्द करें',
      'CANCEL': 'रद्द करें',
      'Logout': 'लॉग आउट',
      'LOGOUT': 'लॉग आउट',
      'Logging out...': 'लॉग आउट हो रहा है...',
    },
    'ta': {
      'Identity Verification': 'அடையாளச் சரிபார்ப்பு',
      'Verify Email': 'மின்னஞ்சலைச் சரிபார்க்கவும்',
      'Enter OTP': 'OTP உள்ளிடவும்',
      'Ask Retail Mind': 'Retail Mind-ஐக் கேளுங்கள்',
      'Daily Closing': 'தினசரி நிறைவு',
      "Today's Total Revenue": 'இன்றைய மொத்த வருவாய்',
      'Online Orders': 'ஆன்லைன் ஆர்டர்கள்',
      'More': 'மேலும்',
      'Your shop workspace': 'உங்கள் கடைப் பணியிடம்',
      'Manage your shop': 'உங்கள் கடையை நிர்வகிக்கவும்',
      'Offline-first workspace': 'ஆஃப்லைனிலும் செயல்படும் பணியிடம்',
      'Retail Growth': 'சில்லறை வளர்ச்சி',
      'Retail Growth Suite': 'சில்லறை வளர்ச்சிக் கருவிகள்',
      'Khata & Udhar': 'கணக்கு மற்றும் கடன்',
      'Khata & Pending Udhar': 'கணக்கு மற்றும் நிலுவைக் கடன்',
      'Invoice Analytics': 'விலைப்பட்டியல் பகுப்பாய்வு',
      'Export Summary': 'சுருக்கத்தை ஏற்றுமதி செய்யவும்',
      'Paid Invoices': 'செலுத்தப்பட்ட விலைப்பட்டியல்கள்',
      'Bank Statement Parser': 'வங்கி அறிக்கை பகுப்பாய்வி',
      'Online Store': 'ஆன்லைன் கடை',
      'Online Store Manager': 'ஆன்லைன் கடை நிர்வாகம்',
      'Enable Online Store': 'ஆன்லைன் கடையைச் செயல்படுத்தவும்',
      'Delivery & Pickup': 'டெலிவரி மற்றும் நேரடி பெறுதல்',
      'Order Constraints': 'ஆர்டர் வரம்புகள்',
      'Create shop coupon': 'கடைக்கான கூப்பனை உருவாக்கவும்',
      'Fixed amount discount': 'நிலையான தொகை தள்ளுபடி',
      'Top Customers by Uncleared Amount':
          'நிலுவைத் தொகையின் அடிப்படையில் முக்கிய வாடிக்கையாளர்கள்',
      'Current Pending Balance:': 'தற்போதைய நிலுவைத் தொகை:',
      'Refresh invoices': 'விலைப்பட்டியல்களைப் புதுப்பிக்கவும்',
      'Search customer, phone or invoice...':
          'வாடிக்கையாளர், தொலைபேசி அல்லது விலைப்பட்டியலைத் தேடவும்...',
      'Items Requested:': 'கோரப்பட்ட பொருட்கள்:',
      'No Staff Accounts': 'பணியாளர் கணக்குகள் இல்லை',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI நுண்ணறிவு, ஸ்மார்ட் சரக்கு, கிளைகள், டெலிவரி, வாடிக்கையாளர் விசுவாசம், விளம்பரங்கள் மற்றும் பாதுகாப்பு.',
      'Ask Retail Mind about payments':
          'பணம் செலுத்துதல் பற்றி Retail Mind-ஐக் கேளுங்கள்',
      'Paid invoices will appear after cloud sync completes.':
          'கிளவுட் ஒத்திசைவு முடிந்ததும் செலுத்தப்பட்ட விலைப்பட்டியல்கள் தோன்றும்.',
      'Newest first': 'புதியவை முதலில்',
      'Oldest first': 'பழையவை முதலில்',
      'Highest amount': 'அதிகத் தொகை',
      'Lowest amount': 'குறைந்த தொகை',
      'Are you the Owner or a Staff Member?':
          'நீங்கள் உரிமையாளரா அல்லது பணியாளரா?',
      'Listen to this page': 'இந்தப் பக்கத்தைக் கேளுங்கள்',
      'Pending Udhar': 'நிலுவைக் கடன்',
      'Ask a business question': 'வணிகக் கேள்வியைக் கேளுங்கள்',
      'Ask your shop anything': 'உங்கள் கடையைப் பற்றி எதையும் கேளுங்கள்',
      'Ask about sales, revenue, customers, stock…':
          'விற்பனை, வருவாய், வாடிக்கையாளர்கள், இருப்பு பற்றி கேளுங்கள்…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'இருப்பு, லாபம், திருப்பி வழங்கல், டெலிவரி அல்லது ஆன்லைன் ஆர்டர்கள் பற்றி கேளுங்கள்…',
      'Actual Cash Being Handed Over': 'ஒப்படைக்கப்படும் உண்மையான பணம்',
      'Opening Cash Balance': 'தொடக்கப் பண இருப்பு',
      'Closing Cash Balance': 'முடிவுப் பண இருப்பு',
      'CONFIRM CLOSING': 'முடிவை உறுதிப்படுத்தவும்',
      'CLOSE DAY & PREPARE REPORT': 'நாளை முடித்து அறிக்கையைத் தயாரிக்கவும்',
      'Please enter the actual cash being handed over':
          'ஒப்படைக்கப்படும் உண்மையான பணத் தொகையை உள்ளிடவும்',
      'Accept Order': 'ஆர்டரை ஏற்கவும்',
      'Mark as Dispatched': 'அனுப்பப்பட்டதாகக் குறிக்கவும்',
      'Mark as Delivered': 'வழங்கப்பட்டதாகக் குறிக்கவும்',
      'Coupon code': 'கூப்பன் குறியீடு',
      'Discount type': 'தள்ளுபடி வகை',
      'Minimum order amount (₹)': 'குறைந்தபட்ச ஆர்டர் தொகை (₹)',
      'Maximum redemptions (optional)': 'அதிகபட்சப் பயன்பாடுகள் (விருப்பம்)',
      'Record Payment': 'பணம் செலுத்தியதைப் பதிவு செய்யவும்',
      'TOTAL OUTSTANDING UDHAR': 'மொத்த நிலுவைக் கடன்',
      'Payment Breakdown': 'கட்டண விவரம்',
      'Statement Summary': 'அறிக்கைச் சுருக்கம்',
      'Net flow for this search': 'இந்தத் தேடலுக்கான நிகரப் பணப்புழக்கம்',
      'Online Payments (UPI/Cards)': 'ஆன்லைன் கட்டணங்கள் (UPI/அட்டைகள்)',
      'Cash on Delivery (COD)': 'டெலிவரியின் போது பணம் (COD)',
      'Search invoice #, customer, phone...':
          'விலைப்பட்டியல் எண், வாடிக்கையாளர் அல்லது தொலைபேசியைத் தேடவும்...',
      'Your payment breakdown will appear when invoices are available.':
          'விலைப்பட்டியல்கள் கிடைக்கும்போது கட்டண விவரம் தோன்றும்.',
      'Logout?': 'வெளியேறவா?',
      'Confirm Logout': 'வெளியேறுவதை உறுதிப்படுத்தவும்',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'நிச்சயமாக வெளியேற விரும்புகிறீர்களா? மீண்டும் உள்நுழையும்போது ஒத்திசைக்கப்பட்ட உங்கள் தரவு பாதுகாப்பாகத் திரும்பும்.',
      'Are you sure you want to log out?':
          'நிச்சயமாக வெளியேற விரும்புகிறீர்களா?',
      'Cancel': 'ரத்து செய்',
      'CANCEL': 'ரத்து செய்',
      'Logout': 'வெளியேறு',
      'LOGOUT': 'வெளியேறு',
      'Logging out...': 'வெளியேறுகிறது...',
    },
    'kn': {
      'Identity Verification': 'ಗುರುತಿನ ಪರಿಶೀಲನೆ',
      'Verify Email': 'ಇಮೇಲ್ ಪರಿಶೀಲಿಸಿ',
      'Enter OTP': 'OTP ನಮೂದಿಸಿ',
      'Ask Retail Mind': 'Retail Mind ಅನ್ನು ಕೇಳಿ',
      'Daily Closing': 'ದೈನಂದಿನ ಮುಕ್ತಾಯ',
      "Today's Total Revenue": 'ಇಂದಿನ ಒಟ್ಟು ಆದಾಯ',
      'Online Orders': 'ಆನ್‌ಲೈನ್ ಆರ್ಡರ್‌ಗಳು',
      'More': 'ಇನ್ನಷ್ಟು',
      'Your shop workspace': 'ನಿಮ್ಮ ಅಂಗಡಿಯ ಕಾರ್ಯಸ್ಥಳ',
      'Manage your shop': 'ನಿಮ್ಮ ಅಂಗಡಿಯನ್ನು ನಿರ್ವಹಿಸಿ',
      'Offline-first workspace': 'ಆಫ್‌ಲೈನ್‌ನಲ್ಲೂ ಕಾರ್ಯನಿರ್ವಹಿಸುವ ಕಾರ್ಯಸ್ಥಳ',
      'Retail Growth': 'ಚಿಲ್ಲರೆ ಬೆಳವಣಿಗೆ',
      'Retail Growth Suite': 'ಚಿಲ್ಲರೆ ಬೆಳವಣಿಗೆ ಪರಿಕರಗಳು',
      'Khata & Udhar': 'ಖಾತೆ ಮತ್ತು ಸಾಲ',
      'Khata & Pending Udhar': 'ಖಾತೆ ಮತ್ತು ಬಾಕಿ ಸಾಲ',
      'Invoice Analytics': 'ಇನ್‌ವಾಯ್ಸ್ ವಿಶ್ಲೇಷಣೆ',
      'Export Summary': 'ಸಾರಾಂಶವನ್ನು ರಫ್ತು ಮಾಡಿ',
      'Paid Invoices': 'ಪಾವತಿಸಿದ ಇನ್‌ವಾಯ್ಸ್‌ಗಳು',
      'Bank Statement Parser': 'ಬ್ಯಾಂಕ್ ಸ್ಟೇಟ್‌ಮೆಂಟ್ ವಿಶ್ಲೇಷಕ',
      'Online Store': 'ಆನ್‌ಲೈನ್ ಅಂಗಡಿ',
      'Online Store Manager': 'ಆನ್‌ಲೈನ್ ಅಂಗಡಿ ನಿರ್ವಾಹಕ',
      'Enable Online Store': 'ಆನ್‌ಲೈನ್ ಅಂಗಡಿಯನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಿ',
      'Delivery & Pickup': 'ವಿತರಣೆ ಮತ್ತು ನೇರವಾಗಿ ಪಡೆದುಕೊಳ್ಳುವುದು',
      'Order Constraints': 'ಆರ್ಡರ್ ಮಿತಿಗಳು',
      'Create shop coupon': 'ಅಂಗಡಿ ಕೂಪನ್ ರಚಿಸಿ',
      'Fixed amount discount': 'ನಿಗದಿತ ಮೊತ್ತದ ರಿಯಾಯಿತಿ',
      'Top Customers by Uncleared Amount':
          'ಬಾಕಿ ಮೊತ್ತದ ಆಧಾರದ ಮೇಲೆ ಪ್ರಮುಖ ಗ್ರಾಹಕರು',
      'Current Pending Balance:': 'ಪ್ರಸ್ತುತ ಬಾಕಿ ಮೊತ್ತ:',
      'Refresh invoices': 'ಇನ್‌ವಾಯ್ಸ್‌ಗಳನ್ನು ರಿಫ್ರೆಶ್ ಮಾಡಿ',
      'Search customer, phone or invoice...':
          'ಗ್ರಾಹಕ, ಫೋನ್ ಅಥವಾ ಇನ್‌ವಾಯ್ಸ್ ಹುಡುಕಿ...',
      'Items Requested:': 'ಕೋರಿದ ವಸ್ತುಗಳು:',
      'No Staff Accounts': 'ಸಿಬ್ಬಂದಿ ಖಾತೆಗಳಿಲ್ಲ',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI ಒಳನೋಟಗಳು, ಸ್ಮಾರ್ಟ್ ದಾಸ್ತಾನು, ಶಾಖೆಗಳು, ವಿತರಣೆ, ಗ್ರಾಹಕ ನಿಷ್ಠೆ, ಪ್ರಚಾರಗಳು ಮತ್ತು ಭದ್ರತೆ.',
      'Ask Retail Mind about payments': 'ಪಾವತಿಗಳ ಬಗ್ಗೆ Retail Mind ಅನ್ನು ಕೇಳಿ',
      'Paid invoices will appear after cloud sync completes.':
          'ಕ್ಲೌಡ್ ಸಿಂಕ್ ಪೂರ್ಣಗೊಂಡ ನಂತರ ಪಾವತಿಸಿದ ಇನ್‌ವಾಯ್ಸ್‌ಗಳು ಕಾಣಿಸುತ್ತವೆ.',
      'Newest first': 'ಹೊಸದವು ಮೊದಲು',
      'Oldest first': 'ಹಳೆಯವು ಮೊದಲು',
      'Highest amount': 'ಅತ್ಯಧಿಕ ಮೊತ್ತ',
      'Lowest amount': 'ಕಡಿಮೆ ಮೊತ್ತ',
      'Are you the Owner or a Staff Member?':
          'ನೀವು ಮಾಲೀಕರಾ ಅಥವಾ ಸಿಬ್ಬಂದಿ ಸದಸ್ಯರಾ?',
      'Listen to this page': 'ಈ ಪುಟವನ್ನು ಆಲಿಸಿ',
      'Pending Udhar': 'ಬಾಕಿ ಸಾಲ',
      'Ask a business question': 'ವ್ಯವಹಾರದ ಬಗ್ಗೆ ಪ್ರಶ್ನೆ ಕೇಳಿ',
      'Ask your shop anything': 'ನಿಮ್ಮ ಅಂಗಡಿಯ ಬಗ್ಗೆ ಏನನ್ನಾದರೂ ಕೇಳಿ',
      'Ask about sales, revenue, customers, stock…':
          'ಮಾರಾಟ, ಆದಾಯ, ಗ್ರಾಹಕರು ಮತ್ತು ದಾಸ್ತಾನು ಬಗ್ಗೆ ಕೇಳಿ…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'ದಾಸ್ತಾನು, ಲಾಭ, ಹಿಂತಿರುಗಿಸುವಿಕೆ, ವಿತರಣೆ ಅಥವಾ ಆನ್‌ಲೈನ್ ಆರ್ಡರ್‌ಗಳ ಬಗ್ಗೆ ಕೇಳಿ…',
      'Actual Cash Being Handed Over': 'ಒಪ್ಪಿಸಲಾಗುತ್ತಿರುವ ನಿಜವಾದ ನಗದು',
      'Opening Cash Balance': 'ಆರಂಭಿಕ ನಗದು ಬಾಕಿ',
      'Closing Cash Balance': 'ಮುಕ್ತಾಯದ ನಗದು ಬಾಕಿ',
      'CONFIRM CLOSING': 'ಮುಕ್ತಾಯವನ್ನು ದೃಢೀಕರಿಸಿ',
      'CLOSE DAY & PREPARE REPORT': 'ದಿನ ಮುಚ್ಚಿ ವರದಿ ಸಿದ್ಧಪಡಿಸಿ',
      'Please enter the actual cash being handed over':
          'ಒಪ್ಪಿಸಲಾಗುತ್ತಿರುವ ನಿಜವಾದ ನಗದನ್ನು ನಮೂದಿಸಿ',
      'Accept Order': 'ಆರ್ಡರ್ ಸ್ವೀಕರಿಸಿ',
      'Mark as Dispatched': 'ರವಾನಿಸಲಾಗಿದೆ ಎಂದು ಗುರುತಿಸಿ',
      'Mark as Delivered': 'ವಿತರಿಸಲಾಗಿದೆ ಎಂದು ಗುರುತಿಸಿ',
      'Coupon code': 'ಕೂಪನ್ ಕೋಡ್',
      'Discount type': 'ರಿಯಾಯಿತಿ ಪ್ರಕಾರ',
      'Minimum order amount (₹)': 'ಕನಿಷ್ಠ ಆರ್ಡರ್ ಮೊತ್ತ (₹)',
      'Maximum redemptions (optional)': 'ಗರಿಷ್ಠ ಬಳಕೆಗಳು (ಐಚ್ಛಿಕ)',
      'Record Payment': 'ಪಾವತಿಯನ್ನು ದಾಖಲಿಸಿ',
      'TOTAL OUTSTANDING UDHAR': 'ಒಟ್ಟು ಬಾಕಿ ಸಾಲ',
      'Payment Breakdown': 'ಪಾವತಿ ವಿವರಗಳು',
      'Statement Summary': 'ಸ್ಟೇಟ್‌ಮೆಂಟ್ ಸಾರಾಂಶ',
      'Net flow for this search': 'ಈ ಹುಡುಕಾಟದ ನಿವ್ವಳ ಹರಿವು',
      'Online Payments (UPI/Cards)': 'ಆನ್‌ಲೈನ್ ಪಾವತಿಗಳು (UPI/ಕಾರ್ಡ್‌ಗಳು)',
      'Cash on Delivery (COD)': 'ವಿತರಣೆಯ ಸಮಯದಲ್ಲಿ ನಗದು (COD)',
      'Search invoice #, customer, phone...':
          'ಇನ್‌ವಾಯ್ಸ್ ಸಂಖ್ಯೆ, ಗ್ರಾಹಕ ಅಥವಾ ಫೋನ್ ಹುಡುಕಿ...',
      'Your payment breakdown will appear when invoices are available.':
          'ಇನ್‌ವಾಯ್ಸ್‌ಗಳು ಲಭ್ಯವಾದಾಗ ಪಾವತಿ ವಿವರಗಳು ಕಾಣಿಸುತ್ತವೆ.',
      'Logout?': 'ಲಾಗ್ ಔಟ್ ಮಾಡಬೇಕೆ?',
      'Confirm Logout': 'ಲಾಗ್ ಔಟ್ ದೃಢೀಕರಿಸಿ',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'ನೀವು ಲಾಗ್ ಔಟ್ ಮಾಡಲು ಖಚಿತವಾಗಿದ್ದೀರಾ? ಮತ್ತೆ ಲಾಗಿನ್ ಮಾಡಿದಾಗ ಸಿಂಕ್ ಮಾಡಿದ ನಿಮ್ಮ ಡೇಟಾ ಸುರಕ್ಷಿತವಾಗಿ ಮರಳುತ್ತದೆ.',
      'Are you sure you want to log out?':
          'ನೀವು ಲಾಗ್ ಔಟ್ ಮಾಡಲು ಖಚಿತವಾಗಿದ್ದೀರಾ?',
      'Cancel': 'ರದ್ದುಮಾಡಿ',
      'CANCEL': 'ರದ್ದುಮಾಡಿ',
      'Logout': 'ಲಾಗ್ ಔಟ್',
      'LOGOUT': 'ಲಾಗ್ ಔಟ್',
      'Logging out...': 'ಲಾಗ್ ಔಟ್ ಆಗುತ್ತಿದೆ...',
    },
    'ml': {
      'Identity Verification': 'തിരിച്ചറിയൽ പരിശോധന',
      'Verify Email': 'ഇമെയിൽ സ്ഥിരീകരിക്കുക',
      'Enter OTP': 'OTP നൽകുക',
      'Ask Retail Mind': 'Retail Mind-നോട് ചോദിക്കുക',
      'Daily Closing': 'ദൈനംദിന സമാപനം',
      "Today's Total Revenue": 'ഇന്നത്തെ ആകെ വരുമാനം',
      'Online Orders': 'ഓൺലൈൻ ഓർഡറുകൾ',
      'More': 'കൂടുതൽ',
      'Your shop workspace': 'നിങ്ങളുടെ കടയുടെ പ്രവർത്തനമേഖല',
      'Manage your shop': 'നിങ്ങളുടെ കട നിയന്ത്രിക്കുക',
      'Offline-first workspace': 'ഓഫ്‌ലൈനിലും പ്രവർത്തിക്കുന്ന ഇടം',
      'Retail Growth': 'റീട്ടെയിൽ വളർച്ച',
      'Retail Growth Suite': 'റീട്ടെയിൽ വളർച്ചാ ഉപകരണങ്ങൾ',
      'Khata & Udhar': 'ഖാതയും കടവും',
      'Khata & Pending Udhar': 'ഖാതയും കുടിശ്ശിക കടവും',
      'Invoice Analytics': 'ഇൻവോയ്സ് വിശകലനം',
      'Export Summary': 'സംഗ്രഹം എക്സ്പോർട്ട് ചെയ്യുക',
      'Paid Invoices': 'പണമടച്ച ഇൻവോയ്സുകൾ',
      'Bank Statement Parser': 'ബാങ്ക് സ്റ്റേറ്റ്മെന്റ് വിശകലനം',
      'Online Store': 'ഓൺലൈൻ കട',
      'Online Store Manager': 'ഓൺലൈൻ കട മാനേജർ',
      'Enable Online Store': 'ഓൺലൈൻ കട പ്രവർത്തനക്ഷമമാക്കുക',
      'Delivery & Pickup': 'ഡെലിവറിയും നേരിട്ട് വാങ്ങലും',
      'Order Constraints': 'ഓർഡർ പരിധികൾ',
      'Create shop coupon': 'കടയ്ക്കായി കൂപ്പൺ സൃഷ്ടിക്കുക',
      'Fixed amount discount': 'നിശ്ചിത തുകയുടെ ഇളവ്',
      'Top Customers by Uncleared Amount':
          'കുടിശ്ശിക തുക പ്രകാരമുള്ള പ്രധാന ഉപഭോക്താക്കൾ',
      'Current Pending Balance:': 'നിലവിലെ കുടിശ്ശിക തുക:',
      'Refresh invoices': 'ഇൻവോയ്സുകൾ പുതുക്കുക',
      'Search customer, phone or invoice...':
          'ഉപഭോക്താവ്, ഫോൺ അല്ലെങ്കിൽ ഇൻവോയ്സ് തിരയുക...',
      'Items Requested:': 'ആവശ്യപ്പെട്ട ഇനങ്ങൾ:',
      'No Staff Accounts': 'സ്റ്റാഫ് അക്കൗണ്ടുകളില്ല',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI ഉൾക്കാഴ്ചകൾ, സ്മാർട്ട് സ്റ്റോക്ക്, ശാഖകൾ, ഡെലിവറി, ഉപഭോക്തൃ വിശ്വസ്തത, പ്രമോഷനുകൾ, സുരക്ഷ.',
      'Ask Retail Mind about payments':
          'പണമിടപാടുകളെക്കുറിച്ച് Retail Mind-നോട് ചോദിക്കുക',
      'Paid invoices will appear after cloud sync completes.':
          'ക്ലൗഡ് സമന്വയം പൂർത്തിയായാൽ പണമടച്ച ഇൻവോയ്സുകൾ കാണിക്കും.',
      'Newest first': 'പുതിയവ ആദ്യം',
      'Oldest first': 'പഴയവ ആദ്യം',
      'Highest amount': 'ഏറ്റവും ഉയർന്ന തുക',
      'Lowest amount': 'ഏറ്റവും കുറഞ്ഞ തുക',
      'Are you the Owner or a Staff Member?': 'നിങ്ങൾ ഉടമയാണോ ജീവനക്കാരനാണോ?',
      'Listen to this page': 'ഈ പേജ് കേൾക്കുക',
      'Pending Udhar': 'കുടിശ്ശിക കടം',
      'Ask a business question': 'ബിസിനസിനെക്കുറിച്ച് ചോദിക്കുക',
      'Ask your shop anything': 'നിങ്ങളുടെ കടയെക്കുറിച്ച് എന്തും ചോദിക്കുക',
      'Ask about sales, revenue, customers, stock…':
          'വിൽപ്പന, വരുമാനം, ഉപഭോക്താക്കൾ, സ്റ്റോക്ക് എന്നിവയെക്കുറിച്ച് ചോദിക്കുക…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'സ്റ്റോക്ക്, ലാഭം, മടക്കങ്ങൾ, ഡെലിവറി അല്ലെങ്കിൽ ഓൺലൈൻ ഓർഡറുകളെക്കുറിച്ച് ചോദിക്കുക…',
      'Actual Cash Being Handed Over': 'കൈമാറുന്ന യഥാർത്ഥ പണം',
      'Opening Cash Balance': 'ആരംഭ പണശേഷി',
      'Closing Cash Balance': 'അവസാന പണശേഷി',
      'CONFIRM CLOSING': 'അവസാനം സ്ഥിരീകരിക്കുക',
      'CLOSE DAY & PREPARE REPORT':
          'ദിവസം അവസാനിപ്പിച്ച് റിപ്പോർട്ട് തയ്യാറാക്കുക',
      'Please enter the actual cash being handed over':
          'കൈമാറുന്ന യഥാർത്ഥ പണത്തുക നൽകുക',
      'Accept Order': 'ഓർഡർ സ്വീകരിക്കുക',
      'Mark as Dispatched': 'അയച്ചതായി അടയാളപ്പെടുത്തുക',
      'Mark as Delivered': 'വിതരണം ചെയ്തതായി അടയാളപ്പെടുത്തുക',
      'Coupon code': 'കൂപ്പൺ കോഡ്',
      'Discount type': 'കിഴിവിന്റെ തരം',
      'Minimum order amount (₹)': 'ഏറ്റവും കുറഞ്ഞ ഓർഡർ തുക (₹)',
      'Maximum redemptions (optional)': 'പരമാവധി ഉപയോഗങ്ങൾ (ഐച്ഛികം)',
      'Record Payment': 'പണമടച്ചത് രേഖപ്പെടുത്തുക',
      'TOTAL OUTSTANDING UDHAR': 'ആകെ കുടിശ്ശിക കടം',
      'Payment Breakdown': 'പണമടയ്ക്കൽ വിശദാംശങ്ങൾ',
      'Statement Summary': 'സ്റ്റേറ്റ്മെന്റ് സംഗ്രഹം',
      'Net flow for this search': 'ഈ തിരച്ചിലിലെ മൊത്തം പണമൊഴുക്ക്',
      'Online Payments (UPI/Cards)': 'ഓൺലൈൻ പേയ്മെന്റുകൾ (UPI/കാർഡുകൾ)',
      'Cash on Delivery (COD)': 'വിതരണസമയത്തെ പണം (COD)',
      'Search invoice #, customer, phone...':
          'ഇൻവോയ്സ് നമ്പർ, ഉപഭോക്താവ് അല്ലെങ്കിൽ ഫോൺ തിരയുക...',
      'Your payment breakdown will appear when invoices are available.':
          'ഇൻവോയ്സുകൾ ലഭ്യമാകുമ്പോൾ പേയ്മെന്റ് വിശദാംശങ്ങൾ കാണിക്കും.',
      'Logout?': 'ലോഗ് ഔട്ട് ചെയ്യണോ?',
      'Confirm Logout': 'ലോഗ് ഔട്ട് സ്ഥിരീകരിക്കുക',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'നിങ്ങൾക്ക് ലോഗ് ഔട്ട് ചെയ്യണമെന്ന് ഉറപ്പാണോ? വീണ്ടും ലോഗിൻ ചെയ്യുമ്പോൾ സമന്വയിപ്പിച്ച ഡാറ്റ സുരക്ഷിതമായി തിരികെ ലഭിക്കും.',
      'Are you sure you want to log out?':
          'നിങ്ങൾക്ക് ലോഗ് ഔട്ട് ചെയ്യണമെന്ന് ഉറപ്പാണോ?',
      'Cancel': 'റദ്ദാക്കുക',
      'CANCEL': 'റദ്ദാക്കുക',
      'Logout': 'ലോഗ് ഔട്ട്',
      'LOGOUT': 'ലോഗ് ഔട്ട്',
      'Logging out...': 'ലോഗ് ഔട്ട് ചെയ്യുന്നു...',
    },
    'mr': {
      'Identity Verification': 'ओळख पडताळणी',
      'Verify Email': 'ईमेलची पडताळणी करा',
      'Enter OTP': 'OTP प्रविष्ट करा',
      'Ask Retail Mind': 'Retail Mind ला विचारा',
      'Daily Closing': 'दैनिक बंद',
      "Today's Total Revenue": 'आजचा एकूण महसूल',
      'Online Orders': 'ऑनलाइन ऑर्डर',
      'More': 'अधिक',
      'Your shop workspace': 'तुमच्या दुकानाचे कार्यक्षेत्र',
      'Manage your shop': 'तुमचे दुकान व्यवस्थापित करा',
      'Offline-first workspace': 'ऑफलाइनमध्येही काम करणारे कार्यक्षेत्र',
      'Retail Growth': 'रिटेल वाढ',
      'Retail Growth Suite': 'रिटेल वाढ साधने',
      'Khata & Udhar': 'खाते आणि उधारी',
      'Khata & Pending Udhar': 'खाते आणि थकबाकी उधारी',
      'Invoice Analytics': 'इनव्हॉइस विश्लेषण',
      'Export Summary': 'सारांश निर्यात करा',
      'Paid Invoices': 'भरलेली इनव्हॉइस',
      'Bank Statement Parser': 'बँक स्टेटमेंट विश्लेषक',
      'Online Store': 'ऑनलाइन दुकान',
      'Online Store Manager': 'ऑनलाइन दुकान व्यवस्थापक',
      'Enable Online Store': 'ऑनलाइन दुकान सुरू करा',
      'Delivery & Pickup': 'डिलिव्हरी आणि प्रत्यक्ष घेणे',
      'Order Constraints': 'ऑर्डर मर्यादा',
      'Create shop coupon': 'दुकानासाठी कूपन तयार करा',
      'Fixed amount discount': 'निश्चित रकमेची सूट',
      'Top Customers by Uncleared Amount': 'थकीत रकमेनुसार प्रमुख ग्राहक',
      'Current Pending Balance:': 'सध्याची थकीत रक्कम:',
      'Refresh invoices': 'इनव्हॉइस रीफ्रेश करा',
      'Search customer, phone or invoice...':
          'ग्राहक, फोन किंवा इनव्हॉइस शोधा...',
      'Items Requested:': 'विनंती केलेल्या वस्तू:',
      'No Staff Accounts': 'कर्मचारी खाती नाहीत',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI माहिती, स्मार्ट साठा, शाखा, डिलिव्हरी, ग्राहक निष्ठा, जाहिराती आणि सुरक्षा.',
      'Ask Retail Mind about payments': 'पेमेंटबद्दल Retail Mind ला विचारा',
      'Paid invoices will appear after cloud sync completes.':
          'क्लाउड सिंक पूर्ण झाल्यावर भरलेली इनव्हॉइस दिसतील.',
      'Newest first': 'नवीन प्रथम',
      'Oldest first': 'सर्वात जुने प्रथम',
      'Highest amount': 'सर्वाधिक रक्कम',
      'Lowest amount': 'सर्वात कमी रक्कम',
      'Are you the Owner or a Staff Member?': 'तुम्ही मालक आहात की कर्मचारी?',
      'Listen to this page': 'हे पान ऐका',
      'Pending Udhar': 'थकीत उधारी',
      'Ask a business question': 'व्यवसायाबद्दल प्रश्न विचारा',
      'Ask your shop anything': 'तुमच्या दुकानाबद्दल काहीही विचारा',
      'Ask about sales, revenue, customers, stock…':
          'विक्री, उत्पन्न, ग्राहक आणि साठ्याबद्दल विचारा…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'साठा, नफा, परतावा, डिलिव्हरी किंवा ऑनलाइन ऑर्डरबद्दल विचारा…',
      'Actual Cash Being Handed Over':
          'सुपूर्द केली जाणारी प्रत्यक्ष रोख रक्कम',
      'Opening Cash Balance': 'सुरुवातीची रोख शिल्लक',
      'Closing Cash Balance': 'अखेरची रोख शिल्लक',
      'CONFIRM CLOSING': 'बंद करण्याची पुष्टी करा',
      'CLOSE DAY & PREPARE REPORT': 'दिवस बंद करून अहवाल तयार करा',
      'Please enter the actual cash being handed over':
          'सुपूर्द केली जाणारी प्रत्यक्ष रोख रक्कम प्रविष्ट करा',
      'Accept Order': 'ऑर्डर स्वीकारा',
      'Mark as Dispatched': 'पाठवले असे चिन्हांकित करा',
      'Mark as Delivered': 'वितरित असे चिन्हांकित करा',
      'Coupon code': 'कूपन कोड',
      'Discount type': 'सवलतीचा प्रकार',
      'Minimum order amount (₹)': 'किमान ऑर्डर रक्कम (₹)',
      'Maximum redemptions (optional)': 'कमाल वापर (ऐच्छिक)',
      'Record Payment': 'पेमेंट नोंदवा',
      'TOTAL OUTSTANDING UDHAR': 'एकूण थकीत उधारी',
      'Payment Breakdown': 'पेमेंट तपशील',
      'Statement Summary': 'स्टेटमेंट सारांश',
      'Net flow for this search': 'या शोधासाठी निव्वळ प्रवाह',
      'Online Payments (UPI/Cards)': 'ऑनलाइन पेमेंट (UPI/कार्ड)',
      'Cash on Delivery (COD)': 'डिलिव्हरीवेळी रोख (COD)',
      'Search invoice #, customer, phone...':
          'इनव्हॉइस क्रमांक, ग्राहक किंवा फोन शोधा...',
      'Your payment breakdown will appear when invoices are available.':
          'इनव्हॉइस उपलब्ध झाल्यावर पेमेंट तपशील दिसतील.',
      'Logout?': 'लॉग आउट करायचे?',
      'Confirm Logout': 'लॉग आउटची पुष्टी करा',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'तुम्हाला लॉग आउट करायचे आहे का? पुन्हा लॉग इन केल्यावर सिंक केलेला डेटा सुरक्षितपणे परत मिळेल.',
      'Are you sure you want to log out?': 'तुम्हाला लॉग आउट करायचे आहे का?',
      'Cancel': 'रद्द करा',
      'CANCEL': 'रद्द करा',
      'Logout': 'लॉग आउट',
      'LOGOUT': 'लॉग आउट',
      'Logging out...': 'लॉग आउट होत आहे...',
    },
    'gu': {
      'Identity Verification': 'ઓળખ ચકાસણી',
      'Verify Email': 'ઇમેઇલ ચકાસો',
      'Enter OTP': 'OTP દાખલ કરો',
      'Ask Retail Mind': 'Retail Mind ને પૂછો',
      'Daily Closing': 'દૈનિક સમાપ્તિ',
      "Today's Total Revenue": 'આજની કુલ આવક',
      'Online Orders': 'ઓનલાઇન ઓર્ડર',
      'More': 'વધુ',
      'Your shop workspace': 'તમારી દુકાનનું કાર્યસ્થળ',
      'Manage your shop': 'તમારી દુકાનનું સંચાલન કરો',
      'Offline-first workspace': 'ઓફલાઇનમાં પણ કાર્યરત કાર્યસ્થળ',
      'Retail Growth': 'રિટેલ વૃદ્ધિ',
      'Retail Growth Suite': 'રિટેલ વૃદ્ધિનાં સાધનો',
      'Khata & Udhar': 'ખાતા અને ઉધાર',
      'Khata & Pending Udhar': 'ખાતા અને બાકી ઉધાર',
      'Invoice Analytics': 'ઇન્વૉઇસ વિશ્લેષણ',
      'Export Summary': 'સારાંશ નિકાસ કરો',
      'Paid Invoices': 'ચૂકવેલા ઇન્વૉઇસ',
      'Bank Statement Parser': 'બેંક સ્ટેટમેન્ટ વિશ્લેષક',
      'Online Store': 'ઓનલાઇન દુકાન',
      'Online Store Manager': 'ઓનલાઇન દુકાન સંચાલક',
      'Enable Online Store': 'ઓનલાઇન દુકાન ચાલુ કરો',
      'Delivery & Pickup': 'ડિલિવરી અને જાતે લઈ જવું',
      'Order Constraints': 'ઓર્ડરની મર્યાદાઓ',
      'Create shop coupon': 'દુકાન માટે કૂપન બનાવો',
      'Fixed amount discount': 'નક્કી રકમનું ડિસ્કાઉન્ટ',
      'Top Customers by Uncleared Amount': 'બાકી રકમ મુજબના મુખ્ય ગ્રાહકો',
      'Current Pending Balance:': 'હાલનું બાકી બેલેન્સ:',
      'Refresh invoices': 'ઇન્વૉઇસ ફરીથી લોડ કરો',
      'Search customer, phone or invoice...':
          'ગ્રાહક, ફોન અથવા ઇન્વૉઇસ શોધો...',
      'Items Requested:': 'વિનંતી કરેલી વસ્તુઓ:',
      'No Staff Accounts': 'કોઈ સ્ટાફ એકાઉન્ટ નથી',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI સમજ, સ્માર્ટ સ્ટોક, શાખાઓ, ડિલિવરી, ગ્રાહક વફાદારી, પ્રમોશન અને સુરક્ષા.',
      'Ask Retail Mind about payments': 'ચૂકવણી વિશે Retail Mind ને પૂછો',
      'Paid invoices will appear after cloud sync completes.':
          'ક્લાઉડ સિંક પૂર્ણ થયા પછી ચૂકવેલા ઇન્વૉઇસ દેખાશે.',
      'Newest first': 'નવું પહેલાં',
      'Oldest first': 'સૌથી જૂનું પહેલાં',
      'Highest amount': 'સૌથી વધુ રકમ',
      'Lowest amount': 'સૌથી ઓછી રકમ',
      'Are you the Owner or a Staff Member?': 'તમે માલિક છો કે સ્ટાફ સભ્ય?',
      'Listen to this page': 'આ પાનું સાંભળો',
      'Pending Udhar': 'બાકી ઉધાર',
      'Ask a business question': 'વ્યવસાય વિશે પ્રશ્ન પૂછો',
      'Ask your shop anything': 'તમારી દુકાન વિશે કંઈપણ પૂછો',
      'Ask about sales, revenue, customers, stock…':
          'વેચાણ, આવક, ગ્રાહકો અને સ્ટોક વિશે પૂછો…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'સ્ટોક, નફો, રિટર્ન, ડિલિવરી અથવા ઓનલાઇન ઓર્ડર વિશે પૂછો…',
      'Actual Cash Being Handed Over': 'સોંપવામાં આવતી વાસ્તવિક રોકડ',
      'Opening Cash Balance': 'શરૂઆતની રોકડ બાકી',
      'Closing Cash Balance': 'અંતિમ રોકડ બાકી',
      'CONFIRM CLOSING': 'સમાપ્તિની પુષ્ટિ કરો',
      'CLOSE DAY & PREPARE REPORT': 'દિવસ બંધ કરીને અહેવાલ તૈયાર કરો',
      'Please enter the actual cash being handed over':
          'સોંપવામાં આવતી વાસ્તવિક રોકડ રકમ દાખલ કરો',
      'Accept Order': 'ઓર્ડર સ્વીકારો',
      'Mark as Dispatched': 'મોકલેલ તરીકે ચિહ્નિત કરો',
      'Mark as Delivered': 'પહોંચાડેલ તરીકે ચિહ્નિત કરો',
      'Coupon code': 'કૂપન કોડ',
      'Discount type': 'ડિસ્કાઉન્ટનો પ્રકાર',
      'Minimum order amount (₹)': 'ઓર્ડરની ન્યૂનતમ રકમ (₹)',
      'Maximum redemptions (optional)': 'મહત્તમ ઉપયોગ (વૈકલ્પિક)',
      'Record Payment': 'ચુકવણી નોંધો',
      'TOTAL OUTSTANDING UDHAR': 'કુલ બાકી ઉધાર',
      'Payment Breakdown': 'ચુકવણીની વિગતો',
      'Statement Summary': 'સ્ટેટમેન્ટ સારાંશ',
      'Net flow for this search': 'આ શોધ માટેનો ચોખ્ખો પ્રવાહ',
      'Online Payments (UPI/Cards)': 'ઓનલાઇન ચુકવણીઓ (UPI/કાર્ડ)',
      'Cash on Delivery (COD)': 'ડિલિવરી વખતે રોકડ (COD)',
      'Search invoice #, customer, phone...':
          'ઇન્વૉઇસ નંબર, ગ્રાહક અથવા ફોન શોધો...',
      'Your payment breakdown will appear when invoices are available.':
          'ઇન્વૉઇસ ઉપલબ્ધ થશે ત્યારે ચુકવણીની વિગતો દેખાશે.',
      'Logout?': 'લૉગઆઉટ કરવું છે?',
      'Confirm Logout': 'લૉગઆઉટની પુષ્ટિ કરો',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'શું તમે લૉગઆઉટ કરવા માંગો છો? ફરીથી લૉગિન કરશો ત્યારે સમન્વયિત ડેટા સુરક્ષિત રીતે પાછો મળશે.',
      'Are you sure you want to log out?': 'શું તમે લૉગઆઉટ કરવા માંગો છો?',
      'Cancel': 'રદ કરો',
      'CANCEL': 'રદ કરો',
      'Logout': 'લૉગઆઉટ',
      'LOGOUT': 'લૉગઆઉટ',
      'Logging out...': 'લૉગઆઉટ થઈ રહ્યું છે...',
    },
    'pa': {
      'Identity Verification': 'ਪਛਾਣ ਦੀ ਪੁਸ਼ਟੀ',
      'Verify Email': 'ਈਮੇਲ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ',
      'Enter OTP': 'OTP ਦਰਜ ਕਰੋ',
      'Ask Retail Mind': 'Retail Mind ਨੂੰ ਪੁੱਛੋ',
      'Daily Closing': 'ਰੋਜ਼ਾਨਾ ਸਮਾਪਤੀ',
      "Today's Total Revenue": 'ਅੱਜ ਦੀ ਕੁੱਲ ਆਮਦਨ',
      'Online Orders': 'ਆਨਲਾਈਨ ਆਰਡਰ',
      'More': 'ਹੋਰ',
      'Your shop workspace': 'ਤੁਹਾਡੀ ਦੁਕਾਨ ਦਾ ਕਾਰਜ-ਖੇਤਰ',
      'Manage your shop': 'ਆਪਣੀ ਦੁਕਾਨ ਸੰਭਾਲੋ',
      'Offline-first workspace': 'ਆਫਲਾਈਨ ਵੀ ਕੰਮ ਕਰਨ ਵਾਲਾ ਕਾਰਜ-ਖੇਤਰ',
      'Retail Growth': 'ਰਿਟੇਲ ਵਿਕਾਸ',
      'Retail Growth Suite': 'ਰਿਟੇਲ ਵਿਕਾਸ ਦੇ ਸਾਧਨ',
      'Khata & Udhar': 'ਖਾਤਾ ਅਤੇ ਉਧਾਰ',
      'Khata & Pending Udhar': 'ਖਾਤਾ ਅਤੇ ਬਕਾਇਆ ਉਧਾਰ',
      'Invoice Analytics': 'ਇਨਵੌਇਸ ਵਿਸ਼ਲੇਸ਼ਣ',
      'Export Summary': 'ਸੰਖੇਪ ਐਕਸਪੋਰਟ ਕਰੋ',
      'Paid Invoices': 'ਭੁਗਤਾਨ ਕੀਤੇ ਇਨਵੌਇਸ',
      'Bank Statement Parser': 'ਬੈਂਕ ਸਟੇਟਮੈਂਟ ਵਿਸ਼ਲੇਸ਼ਕ',
      'Online Store': 'ਆਨਲਾਈਨ ਦੁਕਾਨ',
      'Online Store Manager': 'ਆਨਲਾਈਨ ਦੁਕਾਨ ਪ੍ਰਬੰਧਕ',
      'Enable Online Store': 'ਆਨਲਾਈਨ ਦੁਕਾਨ ਚਾਲੂ ਕਰੋ',
      'Delivery & Pickup': 'ਡਿਲਿਵਰੀ ਅਤੇ ਖੁਦ ਲੈਣਾ',
      'Order Constraints': 'ਆਰਡਰ ਦੀਆਂ ਹੱਦਾਂ',
      'Create shop coupon': 'ਦੁਕਾਨ ਲਈ ਕੂਪਨ ਬਣਾਓ',
      'Fixed amount discount': 'ਨਿਸ਼ਚਿਤ ਰਕਮ ਦੀ ਛੂਟ',
      'Top Customers by Uncleared Amount': 'ਬਕਾਇਆ ਰਕਮ ਅਨੁਸਾਰ ਮੁੱਖ ਗਾਹਕ',
      'Current Pending Balance:': 'ਮੌਜੂਦਾ ਬਕਾਇਆ ਰਕਮ:',
      'Refresh invoices': 'ਇਨਵੌਇਸ ਤਾਜ਼ਾ ਕਰੋ',
      'Search customer, phone or invoice...': 'ਗਾਹਕ, ਫ਼ੋਨ ਜਾਂ ਇਨਵੌਇਸ ਖੋਜੋ...',
      'Items Requested:': 'ਮੰਗੀਆਂ ਗਈਆਂ ਚੀਜ਼ਾਂ:',
      'No Staff Accounts': 'ਕੋਈ ਸਟਾਫ਼ ਖਾਤਾ ਨਹੀਂ',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI ਜਾਣਕਾਰੀ, ਸਮਾਰਟ ਸਟਾਕ, ਸ਼ਾਖਾਵਾਂ, ਡਿਲਿਵਰੀ, ਗਾਹਕ ਵਫ਼ਾਦਾਰੀ, ਪ੍ਰਚਾਰ ਅਤੇ ਸੁਰੱਖਿਆ।',
      'Ask Retail Mind about payments': 'ਭੁਗਤਾਨਾਂ ਬਾਰੇ Retail Mind ਨੂੰ ਪੁੱਛੋ',
      'Paid invoices will appear after cloud sync completes.':
          'ਕਲਾਉਡ ਸਿੰਕ ਪੂਰਾ ਹੋਣ ਤੋਂ ਬਾਅਦ ਭੁਗਤਾਨ ਕੀਤੇ ਇਨਵੌਇਸ ਦਿਖਣਗੇ।',
      'Newest first': 'ਨਵੇਂ ਪਹਿਲਾਂ',
      'Oldest first': 'ਪੁਰਾਣੇ ਪਹਿਲਾਂ',
      'Highest amount': 'ਸਭ ਤੋਂ ਵੱਧ ਰਕਮ',
      'Lowest amount': 'ਸਭ ਤੋਂ ਘੱਟ ਰਕਮ',
      'Are you the Owner or a Staff Member?':
          'ਕੀ ਤੁਸੀਂ ਮਾਲਕ ਹੋ ਜਾਂ ਸਟਾਫ਼ ਮੈਂਬਰ?',
      'Listen to this page': 'ਇਹ ਪੰਨਾ ਸੁਣੋ',
      'Pending Udhar': 'ਬਕਾਇਆ ਉਧਾਰ',
      'Ask a business question': 'ਕਾਰੋਬਾਰ ਬਾਰੇ ਸਵਾਲ ਪੁੱਛੋ',
      'Ask your shop anything': 'ਆਪਣੀ ਦੁਕਾਨ ਬਾਰੇ ਕੁਝ ਵੀ ਪੁੱਛੋ',
      'Ask about sales, revenue, customers, stock…':
          'ਵਿਕਰੀ, ਆਮਦਨ, ਗਾਹਕਾਂ ਅਤੇ ਸਟਾਕ ਬਾਰੇ ਪੁੱਛੋ…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'ਸਟਾਕ, ਮੁਨਾਫ਼ੇ, ਵਾਪਸੀ, ਡਿਲਿਵਰੀ ਜਾਂ ਆਨਲਾਈਨ ਆਰਡਰਾਂ ਬਾਰੇ ਪੁੱਛੋ…',
      'Actual Cash Being Handed Over': 'ਸੌਂਪੀ ਜਾ ਰਹੀ ਅਸਲ ਨਕਦੀ',
      'Opening Cash Balance': 'ਸ਼ੁਰੂਆਤੀ ਨਕਦ ਬਕਾਇਆ',
      'Closing Cash Balance': 'ਬੰਦ ਹੋਣ ਵੇਲੇ ਨਕਦ ਬਕਾਇਆ',
      'CONFIRM CLOSING': 'ਸਮਾਪਤੀ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ',
      'CLOSE DAY & PREPARE REPORT': 'ਦਿਨ ਬੰਦ ਕਰਕੇ ਰਿਪੋਰਟ ਤਿਆਰ ਕਰੋ',
      'Please enter the actual cash being handed over':
          'ਸੌਂਪੀ ਜਾ ਰਹੀ ਅਸਲ ਨਕਦੀ ਦੀ ਰਕਮ ਦਰਜ ਕਰੋ',
      'Accept Order': 'ਆਰਡਰ ਸਵੀਕਾਰ ਕਰੋ',
      'Mark as Dispatched': 'ਭੇਜਿਆ ਗਿਆ ਚਿੰਨ੍ਹਿਤ ਕਰੋ',
      'Mark as Delivered': 'ਡਿਲਿਵਰ ਕੀਤਾ ਚਿੰਨ੍ਹਿਤ ਕਰੋ',
      'Coupon code': 'ਕੂਪਨ ਕੋਡ',
      'Discount type': 'ਛੂਟ ਦੀ ਕਿਸਮ',
      'Minimum order amount (₹)': 'ਘੱਟੋ-ਘੱਟ ਆਰਡਰ ਰਕਮ (₹)',
      'Maximum redemptions (optional)': 'ਵੱਧ ਤੋਂ ਵੱਧ ਵਰਤੋਂ (ਵਿਕਲਪਿਕ)',
      'Record Payment': 'ਭੁਗਤਾਨ ਦਰਜ ਕਰੋ',
      'TOTAL OUTSTANDING UDHAR': 'ਕੁੱਲ ਬਕਾਇਆ ਉਧਾਰ',
      'Payment Breakdown': 'ਭੁਗਤਾਨ ਵੇਰਵਾ',
      'Statement Summary': 'ਸਟੇਟਮੈਂਟ ਸਾਰ',
      'Net flow for this search': 'ਇਸ ਖੋਜ ਲਈ ਕੁੱਲ ਨਕਦੀ ਪ੍ਰਵਾਹ',
      'Online Payments (UPI/Cards)': 'ਆਨਲਾਈਨ ਭੁਗਤਾਨ (UPI/ਕਾਰਡ)',
      'Cash on Delivery (COD)': 'ਡਿਲਿਵਰੀ ਵੇਲੇ ਨਕਦ (COD)',
      'Search invoice #, customer, phone...':
          'ਇਨਵੌਇਸ ਨੰਬਰ, ਗਾਹਕ ਜਾਂ ਫ਼ੋਨ ਖੋਜੋ...',
      'Your payment breakdown will appear when invoices are available.':
          'ਇਨਵੌਇਸ ਉਪਲਬਧ ਹੋਣ ’ਤੇ ਭੁਗਤਾਨ ਵੇਰਵਾ ਦਿਖੇਗਾ।',
      'Logout?': 'ਲੌਗ ਆਉਟ ਕਰਨਾ ਹੈ?',
      'Confirm Logout': 'ਲੌਗ ਆਉਟ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'ਕੀ ਤੁਸੀਂ ਲੌਗ ਆਉਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ? ਦੁਬਾਰਾ ਲੌਗ ਇਨ ਕਰਨ ’ਤੇ ਤੁਹਾਡਾ ਸਿੰਕ ਕੀਤਾ ਡਾਟਾ ਸੁਰੱਖਿਅਤ ਵਾਪਸ ਆ ਜਾਵੇਗਾ।',
      'Are you sure you want to log out?': 'ਕੀ ਤੁਸੀਂ ਲੌਗ ਆਉਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
      'Cancel': 'ਰੱਦ ਕਰੋ',
      'CANCEL': 'ਰੱਦ ਕਰੋ',
      'Logout': 'ਲੌਗ ਆਉਟ',
      'LOGOUT': 'ਲੌਗ ਆਉਟ',
      'Logging out...': 'ਲੌਗ ਆਉਟ ਹੋ ਰਿਹਾ ਹੈ...',
    },
    'bn': {
      'Identity Verification': 'পরিচয় যাচাই',
      'Verify Email': 'ইমেল যাচাই করুন',
      'Enter OTP': 'OTP লিখুন',
      'Ask Retail Mind': 'Retail Mind-কে জিজ্ঞাসা করুন',
      'Daily Closing': 'দৈনিক সমাপ্তি',
      "Today's Total Revenue": 'আজকের মোট আয়',
      'Online Orders': 'অনলাইন অর্ডার',
      'More': 'আরও',
      'Your shop workspace': 'আপনার দোকানের কর্মক্ষেত্র',
      'Manage your shop': 'আপনার দোকান পরিচালনা করুন',
      'Offline-first workspace': 'অফলাইনেও কাজ করে এমন কর্মক্ষেত্র',
      'Retail Growth': 'রিটেল বৃদ্ধি',
      'Retail Growth Suite': 'রিটেল বৃদ্ধির সরঞ্জাম',
      'Khata & Udhar': 'খাতা ও ধার',
      'Khata & Pending Udhar': 'খাতা ও বকেয়া ধার',
      'Invoice Analytics': 'ইনভয়েস বিশ্লেষণ',
      'Export Summary': 'সারাংশ রপ্তানি করুন',
      'Paid Invoices': 'পরিশোধিত ইনভয়েস',
      'Bank Statement Parser': 'ব্যাঙ্ক স্টেটমেন্ট বিশ্লেষক',
      'Online Store': 'অনলাইন দোকান',
      'Online Store Manager': 'অনলাইন দোকান ব্যবস্থাপক',
      'Enable Online Store': 'অনলাইন দোকান চালু করুন',
      'Delivery & Pickup': 'ডেলিভারি ও নিজে সংগ্রহ',
      'Order Constraints': 'অর্ডারের সীমা',
      'Create shop coupon': 'দোকানের কুপন তৈরি করুন',
      'Fixed amount discount': 'নির্দিষ্ট অঙ্কের ছাড়',
      'Top Customers by Uncleared Amount':
          'বকেয়ার পরিমাণ অনুযায়ী শীর্ষ গ্রাহক',
      'Current Pending Balance:': 'বর্তমান বকেয়া ব্যালেন্স:',
      'Refresh invoices': 'ইনভয়েস রিফ্রেশ করুন',
      'Search customer, phone or invoice...':
          'গ্রাহক, ফোন বা ইনভয়েস খুঁজুন...',
      'Items Requested:': 'অনুরোধ করা পণ্য:',
      'No Staff Accounts': 'কোনও কর্মী অ্যাকাউন্ট নেই',
      'AI insights, smart inventory, branches, delivery, loyalty, promotions and security.':
          'AI অন্তর্দৃষ্টি, স্মার্ট মজুত, শাখা, ডেলিভারি, গ্রাহক আনুগত্য, প্রচার ও নিরাপত্তা।',
      'Ask Retail Mind about payments':
          'পেমেন্ট সম্পর্কে Retail Mind-কে জিজ্ঞাসা করুন',
      'Paid invoices will appear after cloud sync completes.':
          'ক্লাউড সিঙ্ক সম্পূর্ণ হলে পরিশোধিত ইনভয়েস দেখা যাবে।',
      'Newest first': 'নতুনগুলি আগে',
      'Oldest first': 'পুরোনোগুলি আগে',
      'Highest amount': 'সর্বোচ্চ পরিমাণ',
      'Lowest amount': 'সর্বনিম্ন পরিমাণ',
      'Are you the Owner or a Staff Member?': 'আপনি কি মালিক, নাকি কর্মী?',
      'Listen to this page': 'এই পৃষ্ঠাটি শুনুন',
      'Pending Udhar': 'বকেয়া ধার',
      'Ask a business question': 'ব্যবসা সম্পর্কে প্রশ্ন করুন',
      'Ask your shop anything':
          'আপনার দোকান সম্পর্কে যেকোনও কিছু জিজ্ঞাসা করুন',
      'Ask about sales, revenue, customers, stock…':
          'বিক্রি, আয়, গ্রাহক ও মজুত সম্পর্কে জিজ্ঞাসা করুন…',
      'Ask about stock, profit, returns, delivery or online orders…':
          'মজুত, লাভ, ফেরত, ডেলিভারি বা অনলাইন অর্ডার সম্পর্কে জিজ্ঞাসা করুন…',
      'Actual Cash Being Handed Over': 'হস্তান্তর করা প্রকৃত নগদ',
      'Opening Cash Balance': 'শুরুর নগদ ব্যালেন্স',
      'Closing Cash Balance': 'শেষের নগদ ব্যালেন্স',
      'CONFIRM CLOSING': 'সমাপ্তি নিশ্চিত করুন',
      'CLOSE DAY & PREPARE REPORT': 'দিন বন্ধ করে রিপোর্ট তৈরি করুন',
      'Please enter the actual cash being handed over':
          'হস্তান্তর করা প্রকৃত নগদের পরিমাণ লিখুন',
      'Accept Order': 'অর্ডার গ্রহণ করুন',
      'Mark as Dispatched': 'পাঠানো হয়েছে চিহ্নিত করুন',
      'Mark as Delivered': 'ডেলিভারি হয়েছে চিহ্নিত করুন',
      'Coupon code': 'কুপন কোড',
      'Discount type': 'ছাড়ের ধরন',
      'Minimum order amount (₹)': 'সর্বনিম্ন অর্ডারের পরিমাণ (₹)',
      'Maximum redemptions (optional)': 'সর্বোচ্চ ব্যবহার (ঐচ্ছিক)',
      'Record Payment': 'পেমেন্ট নথিভুক্ত করুন',
      'TOTAL OUTSTANDING UDHAR': 'মোট বকেয়া ধার',
      'Payment Breakdown': 'পেমেন্টের বিবরণ',
      'Statement Summary': 'স্টেটমেন্টের সারাংশ',
      'Net flow for this search': 'এই অনুসন্ধানের নিট প্রবাহ',
      'Online Payments (UPI/Cards)': 'অনলাইন পেমেন্ট (UPI/কার্ড)',
      'Cash on Delivery (COD)': 'ডেলিভারির সময় নগদ (COD)',
      'Search invoice #, customer, phone...':
          'ইনভয়েস নম্বর, গ্রাহক বা ফোন খুঁজুন...',
      'Your payment breakdown will appear when invoices are available.':
          'ইনভয়েস পাওয়া গেলে পেমেন্টের বিবরণ দেখা যাবে।',
      'Logout?': 'লগ আউট করবেন?',
      'Confirm Logout': 'লগ আউট নিশ্চিত করুন',
      'Are you sure you want to logout? Your synced data will safely return when you log back in.':
          'আপনি কি লগ আউট করতে চান? আবার লগ ইন করলে আপনার সিঙ্ক করা ডেটা নিরাপদে ফিরে আসবে।',
      'Are you sure you want to log out?': 'আপনি কি লগ আউট করতে চান?',
      'Cancel': 'বাতিল করুন',
      'CANCEL': 'বাতিল করুন',
      'Logout': 'লগ আউট',
      'LOGOUT': 'লগ আউট',
      'Logging out...': 'লগ আউট হচ্ছে...',
    },
  };

  // Language map
  static final Map<String, Map<String, String>> translations = {
    'en': {
      'appTitle': 'RETAIL MIND',
      'usernameOrEmail': 'Username or email',
      'easyBilling': 'Easy Billing',
      'betterProfits': 'Better Profits',
      'signInGuidance': 'Listen to sign-in guidance',
      'voiceInstructionsLanguage': 'Get voice instructions in your language',
      'playVoiceGuidance': 'Play guidance',
      'stopVoiceGuidance': 'Stop speaking',
      'continueWithGoogle': 'Continue with Google',
      'noAccount': "Don't have an account?",
      'listenRegisterGuidance': 'Listen to registration guidance',
      'dataProtected': 'Your data is protected',
      'secureAndSafe': 'Secure & Safe',
      'growBusinessInLanguage': 'Grow Your Business\nin Your Language',
      'or': 'OR',
      'signingIn': 'Signing you in',
      'verifyingAccount': 'Verifying your account...',
      'creatingAccount': 'Creating your account',
      'registeringShopSync':
          'Securely registering your shop and syncing the backend',
      'tagline': 'Smart Analytics & Billing Platform',
      'email': 'Email',
      'password': 'Password',
      'login': 'LOGIN',
      'register': 'REGISTER',
      'signIn': 'SIGN IN',
      'createAccount': 'CREATE NEW ACCOUNT',
      'signUp': 'SIGN UP',
      'enterEmail': 'Enter your email',
      'enterPassword': 'Enter your password',
      'confirmPassword': 'Confirm password',
      'userName': 'User Name',
      'shopName': 'Shop Name',
      'location': 'Location',
      'invalidCredentials': 'Invalid credentials',
      'connectionError': 'Connection error',
      'welcome': 'Welcome Back',
      'enterCredentials': 'Enter your credentials to continue',
      'dashboard': 'Dashboard',
      'sales': 'Sales',
      'query': 'Query',
      'giftCard': 'Gift Card',
      'bills': 'Bills',
      'insights': 'Insights',
      'settings': 'Settings',
      'logout': 'Logout',
      'language': 'Language',
      'selectLanguage': 'Select Language',
      'darkMode': 'Dark Mode',
      'notification': 'Notifications',
      'about': 'About',
      'share': 'Share',
      'help': 'Help',
      'profile': 'Profile',
      'forgotPassword': 'Forgot Password?',
      'welcomeBack': 'Welcome back,',
      'salesByMonth': 'Sales by Month',
      'salesByWeek': 'Sales by Week',
      'salesByYear': 'Sales by Year',
      'searchQuery': 'Search Query',
      'dataUpload': 'Data Upload',
      'addSale': 'Add Sale',
      'totalAmount': 'TOTAL AMOUNT',
      'recordedSuccess': 'Recorded successfully!',
      'recordedLocally': 'Saved locally!',
      'askMeAnything': 'Ask me anything...',
      'aiAssistant': 'AI Assistant',
      'alwaysHere': 'Always here to help',
      'performanceOverview': 'Performance Overview',
      'transactions': 'Transactions',
      'avgOrder': 'Avg. Order',
      'products': 'Products',
      'quickActions': 'Quick Actions',
      'getInsights': 'Get Insights',
      'today': 'Today',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
      'showing': 'Showing',
      'phone': 'Phone',
      'owner': 'Owner',
      'website': 'Website',
      'shopkeeper': 'SHOPKEEPER',
      'shareCard': 'Share Card',
      'viewBack': 'View Back',
      'viewFront': 'View Front',
      'goToDashboard': 'Go to Dashboard',
      'tapToFlip': 'Tap to flip for QR code',
      'tapToSeeFront': 'Tap to see front',
      'scanToConnect': 'SCAN TO CONNECT',
      'orScan': 'OR SCAN',
      'allContactIncluded': 'All contact information included',
      'personalInfo': 'Personal Info',
      'shopDetails': 'Shop Details',
      'security': 'Security',
      'fullName': 'Full Name',
      'emailAddress': 'Email Address',
      'phoneNumber': 'Phone Number',
      'shopType': 'Shop Type',
      'taglineOptional': 'Tagline (optional)',
      'websiteOptional': 'Website (optional)',
      'alreadyHaveAccount': 'Already have an account?',
      'joinCommunity': 'Join our community',
      'uploadData': 'Upload Data',
      'analytics': 'Analytics',
      'inventory': 'Inventory',
      'reports': 'Reports',
      'last7Days': 'Last 7 Days',
      'last30Days': 'Last 30 Days',
      'thisYear': 'This Year',
      'noInsights': 'No insights available',
      'goodMorning': 'Good morning! ☀️',
      'synced': 'SYNCED',
      'performanceMessage': "Here's how your shop is performing today",
      'salesTrend': 'Sales Trend',
      'revenueDistribution': 'Revenue Distribution',
      'quantityDistribution': 'Quantity Distribution',
      'revenueLeaders': 'Revenue Leaders',
      'whatChartShows': 'What does this chart show?',
      'askSimpleLanguage': 'Ask in simple language',
      'askQuestionHint': 'Ask a question (e.g. "show sales last week")',
      'askButton': 'Ask',
      'queryTip': 'Tip: Leave file empty to query your database',
      'responseHint': 'Response will appear here',
      'enterProductDetails': 'Enter product details below',
      'addProduct': 'Add Product',
      'generateBill': 'Generate Bill',
      'saveSales': 'Save Sales',
      'paymentMethod': 'Payment Method',
      'cashOffline': 'Cash / Offline',
      'onlineUPI': 'Online / UPI',
      'confirmPayment': 'Confirm Payment Received',
      'paymentConfirmed': 'Payment Confirmed',
      'noSalesData': 'No sales data available',
      'uploadInventory': 'Upload Inventory',
      'selectFile': 'Select File',
      'upload': 'Upload',
      'analyticsOverview': 'Analytics Overview',
      'askToScan': 'Ask customer to scan & pay',
      'scannedBillTitle': 'Scanned Bill',
      'askYourQuestion': 'Ask Your Question',
      'analysisResults': 'Analysis Results',
      'analysisSummary': 'Analysis Summary',
      'detailedData': 'Detailed Data',
      'total': 'Total',
      'revenueShare': 'Revenue Share',
      'topProductsByRevenue': 'Top Products by Revenue',
      'volumeAnalysis': 'Volume Analysis',
      'unitMovementRadar': 'Unit Movement Radar',
      'upwardTrend': 'Upward trend',
      'downwardTrend': 'Downward trend',
      'avgChange': 'avg change',
      'noProductData': 'No product data',
      'volumeByProduct': 'Volume by Product',
      'revenueLeadersDesc':
          'This bar chart highlights the top products by revenue within the selected time frame.',
      'salesTrendDesc':
          "The line chart displays total sales over recent days, giving you an idea of your store's momentum.",
      'revenueDistributionDesc':
          'The pie (donut) chart shows how much each product contributes to overall revenue.',
      'quantityDistributionDesc':
          'The radar chart compares units sold per product, helping you spot high-volume items.',
      'monthlySalesDesc':
          'Track your total sales amount for each month. Identify trends and peak sales periods throughout the year.',
      'weeklySalesDesc':
          'View your sales performance over the last 12 weeks. Spot weekly patterns and week-over-week growth.',
      'yearlySalesDesc':
          'Compare total sales across different years. Perfect for tracking long-term business growth and performance trends.',
      'howToUseTitle': 'How to Use AI Shop Pro',
      'step1Title': '1. Add Sales',
      'step1Desc': 'Log every sale using the Add Sale icon.',
      'step2Title': '2. Manage Inventory',
      'step2Desc': 'Keep track of products by using the Inventory screen.',
      'step3Title': '3. View Reports',
      'step3Desc': 'Check the Reports section for deep analytics.',
      'step4Title': '4. Share Gift Card',
      'step4Desc': 'Send your digital gift card to customers.',
      'step5Title': '5. Accept Payments',
      'step5Desc': 'Show your custom QR to receive payments easily.',
      'gotIt': 'Got it!',
      'dailyPerformanceRating': 'DAILY PERFORMANCE RATING',
      'salesIncreasedBy': "Today's sales increased by",
      'salesDecreasedBy': "Today's sales decreased by",
      'bestHour': 'Best Hour',
      'yesterdayBestProduct': "Yesterday's best product:",
      'noSales': 'No sales',
      'notAvailable': 'N/A',
      'todaySales': 'Today Sales',
      'yesterdaySales': 'Yesterday Sales',
      'analysisAmazing':
          "Amazing! Today you've earned ₹{0}, which is ₹{1} more than yesterday!",
      'analysisProgressing':
          "Progressing! Today's sales are ₹{0}. You're just ₹{1} away from beating yesterday!",
      'analysisWaiting':
          "Waiting for today's first sale. Let's make it a great one!",
      'analysisMatch':
          "Today matches yesterday's performance exactly at ₹{0}! Continuous consistency.",
      'goodMorningName': 'Good morning, {0}! ☀️',
      'goodAfternoonName': 'Good afternoon, {0}! 🌤️',
      'goodEveningName': 'Good evening, {0}! 🌙',
      'tapToUploadQr': 'Tap to upload QR',
      'qrUploadFormat': 'PNG / JPG from gallery',
      'tripleChannelActive': 'TRIPLE-CHANNEL DETECTION ACTIVE',
      'listeningForPayments': 'Listening for UPI, SMS & Screen...',
      'selectDueDate': 'Select Payment Deadline',
      'deadline': 'Deadline',
      'overdue': 'Overdue',
      'pendingPayment': 'Pending Payment',
      'setDeadline': 'Set Deadline',
      'attendance': 'Attendance',
      'customers': 'Customers',
      'addCustomer': 'Add Customer',
      'customerName': 'Customer Name',
      'invoices': 'Invoices',
      'newInvoice': 'New Invoice',
      'noInvoicesFound': 'No Invoices Found',
      'noCustomersYet': 'No Customers Yet',
      'noProductsYet': 'No Products Yet',
      'checkIn': 'Check In',
      'checkOut': 'Check Out',
      'todayStatus': "Today's Status",
      'history': 'History',
      'viewAll': 'View All',
      'mrp': 'Mrp',
      'rate': 'Rate',
      'qty': 'Qty',
      'amt': 'Amt',
      'description': 'Description',
      'billNo': 'Bill No',
      'date': 'Date',
      'time': 'Time',
      'cashier': 'Cashier',
      'counter': 'Counter',
      'cashBill': 'CASH BILL',
      'youHaveSaved': 'You have Saved',
      'thankYouVisitAgain': 'Thank You - Visit Again',
      'items': 'Items',
      'cash': 'Cash',
      'serve': 'Serve',
      'discount': 'Discount',
      'expenses': 'Expenses',
      'workers': 'Workers',
      'backup': 'Backup & Restore',
      'username': "Username",
      'chooseUsername': "Choose a username",
      'shopDisplayName': "Your shop display name",
      'optional': "optional",
      'secure': "Secure",
      'resetCustomerPassword': "Reset customer password",
      'accountEmail': "Account email",
      'sendOtp': "Send OTP",
      'cancel': "Cancel",
      'enterVerificationCode': "Enter verification code",
      'otpSixDigits': "6-digit OTP",
      'verify': "Verify",
      'chooseNewPassword': "Choose a new password",
      'newPasswordAtLeast8': "New password (at least 8 characters)",
      'updatePassword': "Update password",
      'passwordUpdatedLogin':
          "Password updated. Please log in with your new password.",
      'registrationSuccessLogin': "Registration successful! Please login.",
      'welcomeBackShopper': "Welcome back, shopper!",
      'createYourAccount': "Create your account",
      'phoneTenDigits': "Phone (10 digits)",
      'needAccountRegister': "Need an account? Register",
      'alreadyHaveAccountLogin': "Already have an account? Login",
      'backToHome': "Back to Home",
      'unableRequestOtp': "Unable to request a password reset right now.",
      'enterOtpPrompt': "Enter the 6-digit OTP sent to your email.",
      'invalidExpiredOtp': "Invalid or expired OTP.",
      'otpUnavailable': "Unable to verify the OTP.",
      'passwordMinLength':
          "Your new password must contain at least 8 characters.",
      'passwordResetFailed': "Password reset failed. Request a new OTP.",
      'customerLoginInvalidSession':
          "Customer login returned an invalid session.",
      'authenticationFailed': "Authentication failed",
      'paymentStatusLine': "Payment: {method} · {status}",
      'paymentMatchedNotificationHint':
          "Matched from a shop-device notification. This is not a payment-provider confirmation; keep the UPI reference for reconciliation.",
      'paymentPendingHint':
          "Payment is still pending a matching confirmation. Returning from the UPI app does not mark this order paid.",
      'paymentStatusPaid': "Paid",
      'paymentStatusPending': "Pending",
      'paymentStatusCodDue': "Cash due",
      'paymentStatusFailed': "Failed",
      'paymentStatusRefund': "Refunded",
      'paymentStatusPartial': "Partially paid",
      'refresh': "Refresh",
    },
    'te': {
      'appTitle': 'రిటైల్ మైండ్',
      'usernameOrEmail': 'వినియోగదారు పేరు లేదా ఈమెయిల్',
      'easyBilling': 'సులభమైన బిల్లింగ్',
      'betterProfits': 'మెరుగైన లాభాలు',
      'signInGuidance': 'సైన్-ఇన్ సూచనలు వినండి',
      'voiceInstructionsLanguage': 'మీ భాషలో వాయిస్ సూచనలు పొందండి',
      'playVoiceGuidance': 'మార్గదర్శకత్వాన్ని వినండి',
      'stopVoiceGuidance': 'మాట్లాడటం ఆపు',
      'continueWithGoogle': 'Googleతో కొనసాగించండి',
      'noAccount': 'ఖాతా లేదా?',
      'listenRegisterGuidance': 'నమోదు మార్గదర్శకాన్ని వినండి',
      'dataProtected': 'మీ డేటా సురక్షితంగా ఉంది',
      'secureAndSafe': 'సురక్షితం మరియు భద్రం',
      'growBusinessInLanguage': 'మీ భాషలో\nమీ వ్యాపారాన్ని అభివృద్ధి చేయండి',
      'or': 'లేదా',
      'signingIn': 'సైన్ ఇన్ చేస్తున్నారు',
      'verifyingAccount': 'మీ ఖాతాను ధృవీకరిస్తోంది...',
      'creatingAccount': 'మీ ఖాతాను సృష్టిస్తోంది',
      'registeringShopSync':
          'మీ దుకాణాన్ని సురక్షితంగా నమోదు చేసి బ్యాకెండ్‌తో సమకాలీకరిస్తోంది',
      'tagline': 'స్మార్ట్ అనలిటిక్స్ & బిల్లింగ్ ప్లాట్‌ఫారమ్',
      'email': 'ఈమెయిల్',
      'password': 'పాస్‌వర్డ్',
      'login': 'లాగిన్',
      'register': 'నమోదు',
      'signIn': 'సైన్ ఇన్',
      'createAccount': 'కొత్త ఖాతాను సృష్టించండి',
      'signUp': 'సైన్ అప్',
      'enterEmail': 'మీ ఈమెయిల్ నమోదు చేయండి',
      'enterPassword': 'మీ పాస్‌వర్డ్ నమోదు చేయండి',
      'confirmPassword': 'పాస్‌వర్డ్ నిర్ధారించండి',
      'userName': 'యూజర్ పేరు',
      'shopName': 'దుకాణం పేరు',
      'location': 'స్థలం',
      'invalidCredentials': 'చెల్లని ఆధారాలు',
      'connectionError': 'కనెక్షన్ లోపం',
      'welcome': 'స్వాగతం తిరిగి',
      'enterCredentials': 'కొనసాగించడానికి మీ ఆధారాలను నమోదు చేయండి',
      'dashboard': 'డాష్‌బోర్డ్',
      'sales': 'అమ్మకాలు',
      'query': 'ప్రశ్న',
      'giftCard': 'గిఫ్ట్ కార్డ్',
      'bills': 'బిల్లులు',
      'insights': 'అంతర్దృష్టి',
      'settings': 'సెట్టింగ్‌లు',
      'logout': 'లాగ్ అవుట్',
      'language': 'భాష',
      'selectLanguage': 'భాష ఎంచుకోండి',
      'darkMode': 'డార్క్ మోడ్',
      'notification': 'నోటిఫికేషన్‌లు',
      'about': 'గురించి',
      'share': 'షేర్ చేయండి',
      'help': 'సహాయం',
      'profile': 'ప్రొఫైల్',
      'forgotPassword': 'పాస్‌వర్డ్ మర్చిపోయారా?',
      'welcomeBack': 'మళ్ళీ స్వాగతం,',
      'salesByMonth': 'నెలవారీ అమ్మకాలు',
      'salesByWeek': 'వారపు అమ్మకాలు',
      'salesByYear': 'సంవత్సరపు అమ్మకాలు',
      'searchQuery': 'శోధన ప్రశ్న',
      'dataUpload': 'డేటా అప్‌లోడ్',
      'addSale': 'అమ్మకాన్ని జోడించండి',
      'totalAmount': 'మొత్తం వెల',
      'recordedSuccess': 'విజయవంతంగా నమోదైంది!',
      'recordedLocally': 'స్థానికంగా సేవ్ చేయబడింది!',
      'askMeAnything': 'నన్ను ఏదైనా అడగండి...',
      'aiAssistant': 'AI అసిస్టెంట్',
      'alwaysHere': 'ఎల్లప్పుడూ సహాయం చేయడానికి సిద్ధంగా ఉంది',
      'performanceOverview': 'పనితీరు అవలోకనం',
      'transactions': 'లావాదేవీలు',
      'avgOrder': 'సగటు ఆర్డర్',
      'products': 'ఉత్పత్తులు',
      'quickActions': 'త్వరిత చర్యలు',
      'getInsights': 'అంతర్దృష్టులను పొందండి',
      'today': 'ఈ రోజు',
      'week': 'వారం',
      'month': 'నెల',
      'year': 'సంవత్సరం',
      'showing': 'చూపిస్తున్నారు',
      'phone': 'ఫోన్',
      'owner': 'యజమాని',
      'website': 'వెబ్‌సైట్',
      'shopkeeper': 'దుకాణదారుడు',
      'shareCard': 'కార్డును షేర్ చేయండి',
      'viewBack': 'వెనుక వైపు చూడండి',
      'viewFront': 'ముందు వైపు చూడండి',
      'goToDashboard': 'డాష్‌బోర్డ్‌కు వెళ్ళండి',
      'tapToFlip': 'QR కోడ్ కోసం నొక్కండి',
      'tapToSeeFront': 'ముందు వైపు చూడటానికి నొక్కండి',
      'scanToConnect': 'కనెక్ట్ చేయడానికి స్కాన్ చేయండి',
      'orScan': 'లేదా స్కాన్ చేయండి',
      'allContactIncluded': 'అన్ని సంప్రదింపు సమాచారం చేర్చబడింది',
      'personalInfo': 'వ్యక్తిగత సమాచారం',
      'shopDetails': 'దుకాణ వివరాలు',
      'security': 'భద్రత',
      'fullName': 'పూర్తి పేరు',
      'emailAddress': 'ఈమెయిల్ చిరునామా',
      'phoneNumber': 'ఫోన్ నంబర్',
      'shopType': 'దుకాణ రకం',
      'taglineOptional': 'ట్యాగ్‌లైన్ (ఐచ్ఛికం)',
      'websiteOptional': 'వెబ్‌సైట్ (ఐచ్ఛికం)',
      'alreadyHaveAccount': 'ఇప్పటికే ఒక ఖాతా ఉందా?',
      'joinCommunity': 'మా సంఘంలో చేరండి',
      'uploadData': 'డేటా అప్‌లోడ్',
      'analytics': 'విశ్లేషణలు',
      'inventory': 'ఇన్వెంటరీ',
      'reports': 'నివేదికలు',
      'last7Days': 'గత 7 రోజులు',
      'last30Days': 'గత 30 రోజులు',
      'thisYear': 'ఈ సంవత్సరం',
      'noInsights': 'అంతర్దృష్టులు అందుబాటులో లేవు',
      'goodMorning': 'శుభోదయం! ☀️',
      'synced': 'సమకాలీకరించబడింది',
      'performanceMessage': 'ఈరోజు మీ దుకాణం పనితీరు ఇలా ఉంది',
      'refresh': 'తాజా చేయండి',
      'salesTrend': 'విక్రయాల ధోరణి',
      'revenueDistribution': 'ఆదాయ పంపిణీ',
      'quantityDistribution': 'పరిమాణం పంపిణీ',
      'revenueLeaders': 'ఆదాయ నాయకులు',
      'whatChartShows': 'ఈ చార్ట్ ఏమి చూపుతుంది?',
      'askSimpleLanguage': 'సరళమైన భాషలో అడగండి',
      'askQuestionHint': 'ఒక ప్రశ్న అడగండి (ఉదా. "గత వారం అమ్మకాలను చూపించు")',
      'askButton': 'అడగండి',
      'queryTip':
          'చిట్కా: మీ డేటాబేస్‌ను ప్రశ్నించడానికి ఫైల్‌ను ఖాళీగా ఉంచండి',
      'responseHint': 'సమాధానం ఇక్కడ కనిపిస్తుంది',
      'enterProductDetails': 'క్రింద ఉత్పత్తి వివరాలను నమోదు చేయండి',
      'addProduct': 'ఉత్పత్తిని జోడించండి',
      'generateBill': 'బిల్లును రూపొందించండి',
      'saveSales': 'విక్రయాలను సేవ్ చేయండి',
      'paymentMethod': 'చెల్లింపు పద్ధతి',
      'cashOffline': 'నగదు / ఆఫ్ లైన్',
      'onlineUPI': 'ఆన్ లైన్ / UPI',
      'confirmPayment': 'చెల్లింపు అందినట్లు ధృవీకరించండి',
      'paymentConfirmed': 'చెల్లింపు ధృవీకరించబడింది',
      'noSalesData': 'విక్రయాల డేటా అందుబాటులో లేదు',
      'uploadInventory': 'ఇన్వెంటరీని అప్‌లోడ్ చేయండి',
      'selectFile': 'ఫైల్‌ను ఎంచుకోండి',
      'upload': 'అప్‌లోడ్ చేయండి',
      'analyticsOverview': 'విశ్లేషణల అవలోకనం',
      'askToScan': 'స్కాన్ చేసి చెల్లించమని కస్టమర్‌ను కోరండి',
      'scannedBillTitle': 'స్కాన్ చేసిన బిల్లు',
      'askYourQuestion': 'మీ ప్రశ్న అడగండి',
      'analysisResults': 'విశ్లేషణ ఫలితాలు',
      'analysisSummary': 'విశ్లేషణ సారాంశం',
      'detailedData': 'వివరణాత్మక డేటా',
      'total': 'మొత్తం',
      'revenueShare': 'ఆదాయ వాటా',
      'topProductsByRevenue': 'ఆదాయం పరంగా అగ్ర ఉత్పత్తులు',
      'volumeAnalysis': 'పరిమాణం విశ్లేషణ',
      'unitMovementRadar': 'యూనిట్ కదలిక రాడార్',
      'upwardTrend': 'ఎగువ ధోరణి',
      'downwardTrend': 'దిగువ ధోరణి',
      'avgChange': 'సగటు మార్పు',
      'noProductData': 'ఉత్పత్తి డేటా లేదు',
      'volumeByProduct': 'ఉత్పత్తి ద్వారా వాల్యూమ్',
      'revenueLeadersDesc':
          'ఈ బార్ చార్ట్ ఎంచుకున్న సమయ వ్యవధిలో ఆదాయం పరంగా అగ్ర ఉత్పత్తులను హైలైట్ చేస్తుంది.',
      'salesTrendDesc':
          'లైన్ చార్ట్ ఇటీవలి రోజుల్లో మొత్తం అమ్మకాలను ప్రదర్శిస్తుంది, ఇది మీ దుకాణం యొక్క ఊపును తెలియజేస్తుంది.',
      'revenueDistributionDesc':
          'పై (డోనట్) చార్ట్ ప్రతి ఉత్పత్తి మొత్తం ఆదాయానికి ఎంత దోహదం చేస్తుందో చూపుతుంది.',
      'quantityDistributionDesc':
          'రాడార్ చార్ట్ ఉత్పత్తికి విక్రయించిన యూనిట్లను పోల్చి చూస్తుంది, ఇది అధిక-పరిమాణ వస్తువులను గుర్తించడంలో మీకు సహాయపడుతుంది.',
      'monthlySalesDesc':
          'ప్రతి నెల మీ మొత్తం అమ్మకాల మొత్తాన్ని ట్రాక్ చేయండి. ఏడాది పొడవునా ధోరణులు మరియు గరిష్ట విక్రయాల కాలాలను గుర్తించండి.',
      'weeklySalesDesc':
          'గత 12 వారాలలో మీ విక్రయాల పనితీరును చూడండి. వారపు నమూనాలు మరియు వారం వారం వృద్ధిని గుర్తించండి.',
      'yearlySalesDesc':
          'విభిన్న సంవత్సరాల్లో మొత్తం అమ్మకాలను పోల్చండి. దీర్ఘకాలిక వ్యాపార వృద్ధి మరియు పనితీరు ధోరణులను ట్రాక్ చేయడానికి పర్ఫెక్ట్.',
      'howToUseTitle': 'AI షాప్ ప్రో ఉపయోగించడం ఎలా',
      'step1Title': '1. అమ్మకాలను జోడించండి',
      'step1Desc': 'అమ్మకం చిహ్నాన్ని ఉపయోగించి ప్రతి అమ్మకాన్ని నమోదు చేయండి.',
      'step2Title': '2. ఇన్వెంటరీని నిర్వహించండి',
      'step2Desc': 'ఇన్వెంటరీ స్క్రీన్‌ను ఉపయోగించి ఉత్పత్తులను ట్రాక్ చేయండి.',
      'step3Title': '3. నివేదికలను చూడండి',
      'step3Desc': 'లోతైన విశ్లేషణల కోసం నివేదికల విభాగాన్ని తనిఖీ చేయండి.',
      'step4Title': '4. గిఫ్ట్ కార్డ్ షేర్ చేయండి',
      'step4Desc': 'మీ డిజిటల్ గిఫ్ట్ కార్డును వినియోగదారులకు పంపండి.',
      'step5Title': '5. చెల్లింపులను స్వీకరించండి',
      'step5Desc':
          'చెల్లింపులను సులభంగా స్వీకరించడానికి మీ అనుకూల QR ని చూపండి.',
      'gotIt': 'అర్థమైంది!',
      'dailyPerformanceRating': 'రోజువారీ పనితీరు రేటింగ్',
      'salesIncreasedBy': 'నేటి అమ్మకాలు పెరిగాయి',
      'salesDecreasedBy': 'నేటి అమ్మకాలు తగ్గాయి',
      'bestHour': 'ఉత్తమ గంట',
      'yesterdayBestProduct': 'నిన్నటి ఉత్తమ ఉత్పత్తి:',
      'noSales': 'అమ్మకాలు లేవు',
      'notAvailable': 'అందుబాటులో లేదు',
      'todaySales': 'నేటి అమ్మకాలు',
      'yesterdaySales': 'నిన్నటి అమ్మకాలు',
      'analysisAmazing':
          'అద్భుతం! నేడు మీరు ₹{0} సంపాదించారు, ఇది నిన్నటి కంటే ₹{1} ఎక్కువ!',
      'analysisProgressing':
          'పురోగమిస్తోంది! నేటి అమ్మకాలు ₹{0}. నిన్నటిని అధిగమించడానికి మీరు కేవలం ₹{1} దూరంలో ఉన్నారు!',
      'analysisWaiting':
          'నేటి మొదటి అమ్మకం కోసం వేచి చూస్తున్నాము. దీనిని గొప్పగా చేద్దాం!',
      'analysisMatch':
          'నేటి పనితీరు నిన్నటితో సరిగ్గా ₹{0} వద్ద సరిపోయింది! నిరంతర స్థిరత్వం.',
      'goodMorningName': 'శుభోదయం, {0}! ☀️',
      'goodAfternoonName': 'శుభ మధ్యాహ్నం, {0}! 🌤️',
      'goodEveningName': 'శుభ సాయంత్రం, {0}! 🌙',
      'tapToUploadQr': 'QR అప్‌లోడ్ చేయడానికి నొక్కండి',
      'qrUploadFormat': 'PNG / JPG గ్యాలరీ నుండి',
      'tripleChannelActive': 'ట్రిపుల్ ఛానల్ డిటెక్షన్ యాక్టివ్‌గా ఉంది',
      'listeningForPayments': 'UPI, SMS & స్క్రీన్ కోసం వేచి ఉంది...',
      'selectDueDate': 'చెల్లింపు గడువును ఎంచుకోండి',
      'deadline': 'గడువు',
      'overdue': 'గడువు ముగిసింది',
      'pendingPayment': 'పెండింగ్ చెల్లింపు',
      'setDeadline': 'గడువును నిర్ణయించండి',
      'attendance': 'హాజరు',
      'customers': 'వినియోగదారులు',
      'addCustomer': 'వినియోగదారుని జోడించండి',
      'customerName': 'వినియోగదారు పేరు',
      'invoices': 'ఇన్‌వాయిస్‌లు',
      'newInvoice': 'కొత్త ఇన్‌వాయిస్',
      'noInvoicesFound': 'ఇన్‌వాయిస్‌లు కనుగొనబడలేదు',
      'noCustomersYet': 'ఇంకా వినియోగదారులు లేరు',
      'noProductsYet': 'ఇంకా ఉత్పత్తులు లేవు',
      'checkIn': 'చెక్ ఇన్',
      'checkOut': 'చెక్ అవుట్',
      'todayStatus': "నేటి స్థితి",
      'history': 'చరిత్ర',
      'viewAll': 'అన్నీ చూడండి',
      'mrp': 'Mrp',
      'rate': 'రేటు',
      'qty': 'పరిమాణం',
      'amt': 'వెల',
      'description': 'వివరణ',
      'billNo': 'బిల్లు నెం',
      'date': 'తేదీ',
      'time': 'సమయం',
      'cashier': 'క్యాషియర్',
      'counter': 'కౌంటర్',
      'cashBill': 'నగదు బిల్లు',
      'youHaveSaved': 'మీరు పొదుపు చేసారు',
      'thankYouVisitAgain': 'ధన్యవాదాలు - మళ్ళీ రండి',
      'items': 'వస్తువులు',
      'cash': 'నగదు',
      'serve': 'సేవ',
      'discount': 'తగ్గింపు',
      'expenses': 'ఖర్చులు',
      'workers': 'పనివారు',
      'backup': 'బ్యాకప్ & రీస్టోర్',
      'username': "వినియోగదారు పేరు",
      'chooseUsername': "వినియోగదారు పేరును ఎంచుకోండి",
      'shopDisplayName': "మీ దుకాణం ప్రదర్శన పేరు",
      'optional': "ఐచ్ఛికం",
      'secure': "సురక్షితం",
      'resetCustomerPassword': "కస్టమర్ పాస్‌వర్డ్ రీసెట్",
      'accountEmail': "ఖాతా ఇమెయిల్",
      'sendOtp': "OTP పంపండి",
      'cancel': "రద్దు చేయండి",
      'enterVerificationCode': "ధృవీకరణ కోడ్ నమోదు చేయండి",
      'otpSixDigits': "6 అంకెల OTP",
      'verify': "ధృవీకరించండి",
      'chooseNewPassword': "కొత్త పాస్‌వర్డ్ ఎంచుకోండి",
      'newPasswordAtLeast8': "కొత్త పాస్‌వర్డ్ (కనీసం 8 అక్షరాలు)",
      'updatePassword': "పాస్‌వర్డ్ నవీకరించండి",
      'passwordUpdatedLogin':
          "పాస్‌వర్డ్ నవీకరించబడింది. కొత్త పాస్‌వర్డ్‌తో లాగిన్ అవ్వండి.",
      'registrationSuccessLogin': "నమోదు విజయవంతమైంది! దయచేసి లాగిన్ అవ్వండి.",
      'welcomeBackShopper': "మళ్లీ స్వాగతం!",
      'createYourAccount': "మీ ఖాతాను సృష్టించండి",
      'phoneTenDigits': "ఫోన్ (10 అంకెలు)",
      'needAccountRegister': "ఖాతా లేదా? నమోదు చేయండి",
      'alreadyHaveAccountLogin': "ఇప్పటికే ఖాతా ఉందా? లాగిన్ అవ్వండి",
      'backToHome': "హోమ్‌కు తిరిగి వెళ్లండి",
      'unableRequestOtp': "ప్రస్తుతం పాస్‌వర్డ్ రీసెట్ అభ్యర్థించలేకపోయాం.",
      'enterOtpPrompt': "మీ ఇమెయిల్‌కు పంపిన 6 అంకెల OTP నమోదు చేయండి.",
      'invalidExpiredOtp': "OTP చెల్లదు లేదా గడువు ముగిసింది.",
      'otpUnavailable': "OTP ధృవీకరించలేకపోయాం.",
      'passwordMinLength': "కొత్త పాస్‌వర్డ్‌లో కనీసం 8 అక్షరాలు ఉండాలి.",
      'passwordResetFailed':
          "పాస్‌వర్డ్ రీసెట్ విఫలమైంది. కొత్త OTP కోసం అభ్యర్థించండి.",
      'customerLoginInvalidSession': "కస్టమర్ లాగిన్ సెషన్ చెల్లదు.",
      'authenticationFailed': "ధృవీకరణ విఫలమైంది",
      'paymentStatusLine': "చెల్లింపు: {method} · {status}",
      'paymentMatchedNotificationHint':
          "దుకాణం పరికర నోటిఫికేషన్‌తో సరిపోల్చబడింది. ఇది చెల్లింపు ప్రదాత ధృవీకరణ కాదు; సరిపోల్చడానికి UPI రిఫరెన్స్‌ను ఉంచండి.",
      'paymentPendingHint':
          "చెల్లింపుకు సరిపోలే నిర్ధారణ ఇంకా పెండింగ్‌లో ఉంది. UPI యాప్ నుంచి తిరిగి రావడం వల్ల ఈ ఆర్డర్ చెల్లించబడినట్లు కాదు.",
      'paymentStatusPaid': "చెల్లించబడింది",
      'paymentStatusPending': "పెండింగ్‌లో ఉంది",
      'paymentStatusCodDue': "నగదు చెల్లించాలి",
      'paymentStatusFailed': "విఫలమైంది",
      'paymentStatusRefund': "తిరిగి చెల్లించబడింది",
      'paymentStatusPartial': "కొంత చెల్లింపు",
    },
    'hi': {
      'appTitle': 'रिटेल माइंड',
      'usernameOrEmail': 'उपयोगकर्ता नाम या ईमेल',
      'easyBilling': 'आसान बिलिंग',
      'betterProfits': 'बेहतर मुनाफ़ा',
      'signInGuidance': 'साइन-इन निर्देश सुनें',
      'voiceInstructionsLanguage': 'अपनी भाषा में आवाज़ से निर्देश पाएँ',
      'playVoiceGuidance': 'निर्देश सुनें',
      'stopVoiceGuidance': 'बोलना बंद करें',
      'continueWithGoogle': 'Google के साथ जारी रखें',
      'noAccount': 'खाता नहीं है?',
      'listenRegisterGuidance': 'पंजीकरण के निर्देश सुनें',
      'dataProtected': 'आपका डेटा सुरक्षित है',
      'secureAndSafe': 'सुरक्षित',
      'growBusinessInLanguage': 'अपनी भाषा में\nअपना व्यवसाय बढ़ाएँ',
      'or': 'या',
      'signingIn': 'साइन इन हो रहा है',
      'verifyingAccount': 'आपके खाते की पुष्टि हो रही है...',
      'creatingAccount': 'आपका खाता बनाया जा रहा है',
      'registeringShopSync':
          'आपकी दुकान सुरक्षित रूप से पंजीकृत की जा रही है और बैकएंड के साथ सिंक हो रही है',
      'tagline': 'स्मार्ट एनालिटिक्स और बिलिंग प्लेटफॉर्म',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'login': 'लॉगिन',
      'register': 'पंजीकरण',
      'signIn': 'साइन इन',
      'createAccount': 'नया खाता बनाएं',
      'signUp': 'साइन अप',
      'enterEmail': 'अपना ईमेल दर्ज करें',
      'enterPassword': 'अपना पासवर्ड दर्ज करें',
      'confirmPassword': 'पासवर्ड की पुष्टि करें',
      'userName': 'उपयोगकर्ता का नाम',
      'shopName': 'दुकान का नाम',
      'location': 'स्थान',
      'invalidCredentials': 'अमान्य साक्षर',
      'connectionError': 'कनेक्शन त्रुटि',
      'welcome': 'वापस स्वागत है',
      'enterCredentials': 'जारी रखने के लिए अपनी साक्षर दर्ज करें',
      'dashboard': 'डैशबोर्ड',
      'sales': 'विक्रय',
      'query': 'प्रश्न',
      'giftCard': 'गिफ्ट कार्ड',
      'bills': 'बिल',
      'insights': 'अंतर्दृष्टि',
      'settings': 'सेटिंग्स',
      'logout': 'लॉग आउट',
      'language': 'भाषा',
      'selectLanguage': 'भाषा चुनें',
      'darkMode': 'डार्क मोड',
      'notification': 'सूचनाएं',
      'about': 'बारे में',
      'share': 'शेयर करें',
      'help': 'मदद',
      'profile': 'प्रोफ़ाइल',
      'forgotPassword': 'पासवर्ड भूल गए?',
      'welcomeBack': 'आपका स्वागत है,',
      'salesByMonth': 'महीने के अनुसार बिक्री',
      'salesByWeek': 'सप्ताह के अनुसार बिक्री',
      'salesByYear': 'वर्ष के अनुसार बिक्री',
      'searchQuery': 'खोज प्रश्न',
      'dataUpload': 'डेटा अपलोड',
      'addSale': 'बिक्री जोड़ें',
      'totalAmount': 'कुल राशि',
      'recordedSuccess': 'सफलतापूर्वक दर्ज किया गया!',
      'recordedLocally': 'स्थानीय रूप से सहेजा गया!',
      'askMeAnything': 'मुझसे कुछ भी पूछें...',
      'aiAssistant': 'AI सहायक',
      'alwaysHere': 'हमेशा मदद के लिए यहाँ है',
      'performanceOverview': 'प्रदर्शन अवलोकन',
      'transactions': 'लेन-देन',
      'avgOrder': 'औसत ऑर्डर',
      'products': 'उत्पादों',
      'quickActions': 'त्वरित कार्रवाई',
      'getInsights': 'इनसाइट्स प्राप्त करें',
      'today': 'आज',
      'week': 'सप्ताह',
      'month': 'महीना',
      'year': 'साल',
      'showing': 'दिखा रहा है',
      'phone': 'फ़ोन',
      'owner': 'मालिक',
      'website': 'वेबसाइट',
      'shopkeeper': 'दुकानदार',
      'shareCard': 'कार्ड साझा करें',
      'viewBack': 'पीछे का भाग देखें',
      'viewFront': 'सामने का भाग देखें',
      'goToDashboard': 'डैशबोर्ड पर जाएं',
      'tapToFlip': 'QR कोड के लिए टैप करें',
      'tapToSeeFront': 'सामने देखने के लिए टैप करें',
      'scanToConnect': 'कनेक्ट करने के लिए स्कैन करें',
      'orScan': 'या स्कैन करें',
      'allContactIncluded': 'सभी संपर्क जानकारी शामिल है',
      'personalInfo': 'व्यक्तिगत जानकारी',
      'shopDetails': 'दुकान का विवरण',
      'security': 'सुरक्षा',
      'fullName': 'पूरा नाम',
      'emailAddress': 'ईमेल पता',
      'phoneNumber': 'फ़ोन नंबर',
      'shopType': 'दुकान का प्रकार',
      'taglineOptional': 'टैगलाइन (वैकल्पिक)',
      'websiteOptional': 'वेबसाइट (वैकल्पिक)',
      'alreadyHaveAccount': 'क्या आपके पास पहले से एक खाता है?',
      'joinCommunity': 'हमारे समुदाय में शामिल हों',
      'uploadData': 'डेटा अपलोड करें',
      'analytics': 'विश्लेषण',
      'inventory': 'इन्वेंटरी',
      'reports': 'रिपोर्ट',
      'last7Days': 'पिछले 7 दिन',
      'last30Days': 'पिछले 30 दिन',
      'thisYear': 'इस साल',
      'noInsights': 'कोई अंतर्दृष्टि उपलब्ध नहीं है',
      'goodMorning': 'शुभ प्रभात! ☀️',
      'synced': 'सिंक्रोनाइज़्ड',
      'performanceMessage':
          'यहाँ बताया गया है कि आपकी दुकान आज कैसा प्रदर्शन कर रही है',
      'refresh': 'रिफ्रेश करें',
      'salesTrend': 'बिक्री का रुझान',
      'revenueDistribution': 'राजस्व वितरण',
      'quantityDistribution': 'मात्रा वितरण',
      'revenueLeaders': 'राजस्व नेता',
      'whatChartShows': 'यह चार्ट क्या दिखाता है?',
      'askSimpleLanguage': 'सरल भाषा में पूछें',
      'askQuestionHint':
          'एक प्रश्न पूछें (जैसे "पिछले सप्ताह की बिक्री दिखाएं")',
      'askButton': 'पूछें',
      'queryTip': 'टिप: अपने डेटाबेस से पूछने के लिए फ़ाइल को खाली छोड़ दें',
      'responseHint': 'जवाब यहाँ दिखाई देगा',
      'enterProductDetails': 'नीचे उत्पाद विवरण दर्ज करें',
      'addProduct': 'उत्पाद जोड़ें',
      'generateBill': 'बिल जनरेट करें',
      'saveSales': 'बिक्री सहेजें',
      'paymentMethod': 'भुगतान विधि',
      'cashOffline': 'नकद / ऑफलाइन',
      'onlineUPI': 'ऑनलाइन / UPI',
      'confirmPayment': 'भुगतान प्राप्त होने की पुष्टि करें',
      'paymentConfirmed': 'भुगतान की पुष्टि हो गई',
      'noSalesData': 'कोई बिक्री डेटा उपलब्ध नहीं है',
      'uploadInventory': 'माल सूची अपलोड करें',
      'selectFile': 'फ़ाइल चुनें',
      'upload': 'अपलोड करें',
      'analyticsOverview': 'विश्लेषण अवलोकन',
      'askToScan': 'ग्राहक को स्कैन और भुगतान करने के लिए कहें',
      'scannedBillTitle': 'स्कैन किया गया बिल',
      'askYourQuestion': 'अपना प्रश्न पूछें',
      'analysisResults': 'विश्लेषण परिणाम',
      'analysisSummary': 'विश्लेषण सारांश',
      'detailedData': 'विस्तृत डेटा',
      'total': 'कुल',
      'revenueShare': 'राजस्व हिस्सेदारी',
      'topProductsByRevenue': 'राजस्व के आधार पर शीर्ष उत्पाद',
      'volumeAnalysis': 'मात्रा विश्लेषण',
      'unitMovementRadar': 'यूनिट मूवमेंट रडार',
      'upwardTrend': 'ऊर्ध्वगामी रुझान',
      'downwardTrend': 'नीचे की ओर रुझान',
      'avgChange': 'औसत परिवर्तन',
      'noProductData': 'कोई उत्पाद डेटा नहीं',
      'volumeByProduct': 'उत्पाद द्वारा वॉल्यूम',
      'revenueLeadersDesc':
          'यह बार चार्ट चयनित समय सीमा के भीतर राजस्व के आधार पर शीर्ष उत्पादों को उजागर करता है।',
      'salesTrendDesc':
          'लाइन चार्ट पिछले कुछ दिनों में कुल बिक्री को प्रदर्शित करता है, जिससे आपको अपने स्टोर की गति का अंदाज़ा मिलता है।',
      'revenueDistributionDesc':
          'पाई (डोनट) चार्ट दिखाता है कि प्रत्येक उत्पाद कुल राजस्व में कितना योगदान देता है।',
      'quantityDistributionDesc':
          'रडार चार्ट प्रति उत्पाद बेची गई इकाइयों की तुलना करता है, जिससे आपको उच्च-मात्रा वाली वस्तुओं को खोजने में मदद मिलती है।',
      'monthlySalesDesc':
          'प्रत्येक महीने के लिए अपनी कुल बिक्री राशि को ट्रैक करें। पूरे वर्ष रुझानों और चरम बिक्री अवधियों की पहचान करें।',
      'weeklySalesDesc':
          'पिछले 12 हफ्तों में अपनी बिक्री के प्रदर्शन को देखें। साप्ताहिक पैटर्न और सप्ताह-दर-सप्ताह वृद्धि का पता लगाएं।',
      'yearlySalesDesc':
          'विभिन्न वर्षों में कुल बिक्री की तुलना करें। दीर्घकालिक व्यावसायिक विकास और प्रदर्शन रुझानों पर नज़र रखने के लिए बिल्कुल सही।',
      'howToUseTitle': 'AI शॉप प्रो का उपयोग कैसे करें',
      'step1Title': '1. बिक्री जोड़ें',
      'step1Desc': 'ऐड सेल आइकन का उपयोग करके हर बिक्री दर्ज करें।',
      'step2Title': '2. इन्वेंट्री प्रबंधित करें',
      'step2Desc': 'इन्वेंट्री स्क्रीन का उपयोग करके उत्पादों पर नज़र रखें।',
      'step3Title': '3. रिपोर्ट देखें',
      'step3Desc': 'गहन विश्लेषण के लिए रिपोर्ट अनुभाग देखें।',
      'step4Title': '4. गिफ्ट कार्ड साझा करें',
      'step4Desc': 'अपने डिजिटल गिफ्ट कार्ड को ग्राहकों को भेजें।',
      'step5Title': '5. भुगतान स्वीकार करें',
      'step5Desc': 'आसानी से भुगतान प्राप्त करने के लिए अपना कस्टम QR दिखाएं।',
      'gotIt': 'समझ गया!',
      'dailyPerformanceRating': 'दैनिक प्रदर्शन रेटिंग',
      'salesIncreasedBy': 'आज की बिक्री में वृद्धि हुई',
      'salesDecreasedBy': 'आज की बिक्री में कमी आई',
      'bestHour': 'सबसे अच्छा घंटा',
      'yesterdayBestProduct': 'कल का सबसे अच्छा उत्पाद:',
      'noSales': 'कोई बिक्री नहीं',
      'notAvailable': 'उपलब्ध नहीं',
      'todaySales': 'आज की बिक्री',
      'yesterdaySales': 'कल की बिक्री',
      'analysisAmazing':
          'अद्भुत! आज आपने ₹{0} कमाए हैं, जो कल से ₹{1} अधिक है!',
      'analysisProgressing':
          'प्रगति पर है! आज की बिक्री ₹{0} है। आप कल से आगे निकलने के लिए केवल ₹{1} दूर हैं!',
      'analysisWaiting': 'आज की पहली बिक्री का इंतज़ार है। इसे शानदार बनाएं!',
      'analysisMatch':
          'आज का प्रदर्शन कल के ₹{0} के बिल्कुल बराबर है! निरंतर स्थिरता।',
      'goodMorningName': 'शुभ प्रभात, {0}! ☀️',
      'goodAfternoonName': 'शुभ दोपहर, {0}! 🌤️',
      'goodEveningName': 'शुभ संध्या, {0}! 🌙',
      'tapToUploadQr': 'QR अपलोड करने के लिए टैप करें',
      'qrUploadFormat': 'गैलरी से PNG / JPG',
      'tripleChannelActive': 'ट्रिपल-चैनल डिटेक्शन सक्रिय',
      'listeningForPayments': 'UPI, SMS और स्क्रीन की निगरानी...',
      'selectDueDate': 'भुगतान की समय सीमा चुनें',
      'deadline': 'समय सीमा',
      'overdue': 'विलंबित',
      'pendingPayment': 'लंबित भुगतान',
      'setDeadline': 'समय सीमा निर्धारित करें',
      'attendance': 'उपस्थिति',
      'customers': 'ग्राहक',
      'addCustomer': 'ग्राहक जोड़ें',
      'customerName': 'ग्राहक का नाम',
      'invoices': 'चालान',
      'newInvoice': 'नया चालान',
      'noInvoicesFound': 'कोई चालान नहीं मिला',
      'noCustomersYet': 'अभी तक कोई ग्राहक नहीं है',
      'noProductsYet': 'अभी तक कोई उत्पाद नहीं है',
      'checkIn': 'चेक इन',
      'checkOut': 'चेक आउट',
      'todayStatus': "आज की स्थिति",
      'history': 'इतिहास',
      'viewAll': 'सभी देखें',
      'mrp': 'Mrp',
      'rate': 'रेट',
      'qty': 'मात्रा',
      'amt': 'राशि',
      'description': 'विवरण',
      'billNo': 'बिल नंबर',
      'date': 'दिनांक',
      'time': 'समय',
      'cashier': 'कैशियर',
      'counter': 'काउंटर',
      'cashBill': 'नकद बिल',
      'youHaveSaved': 'आपने बचाए',
      'thankYouVisitAgain': 'धन्यवाद - फिर आएं',
      'items': 'वस्तुएं',
      'cash': 'नकद',
      'serve': 'सर्फ',
      'discount': 'छूट',
      'username': "उपयोगकर्ता नाम",
      'chooseUsername': "उपयोगकर्ता नाम चुनें",
      'shopDisplayName': "आपकी दुकान का प्रदर्शित नाम",
      'optional': "वैकल्पिक",
      'secure': "सुरक्षित",
      'resetCustomerPassword': "ग्राहक पासवर्ड रीसेट करें",
      'accountEmail': "खाते का ईमेल",
      'sendOtp': "OTP भेजें",
      'cancel': "रद्द करें",
      'enterVerificationCode': "सत्यापन कोड दर्ज करें",
      'otpSixDigits': "6 अंकों का OTP",
      'verify': "सत्यापित करें",
      'chooseNewPassword': "नया पासवर्ड चुनें",
      'newPasswordAtLeast8': "नया पासवर्ड (कम से कम 8 अक्षर)",
      'updatePassword': "पासवर्ड अपडेट करें",
      'passwordUpdatedLogin':
          "पासवर्ड अपडेट हो गया। कृपया नए पासवर्ड से लॉगिन करें.",
      'registrationSuccessLogin': "पंजीकरण सफल! कृपया लॉगिन करें.",
      'welcomeBackShopper': "फिर से स्वागत है!",
      'createYourAccount': "अपना खाता बनाएं",
      'phoneTenDigits': "फ़ोन (10 अंक)",
      'needAccountRegister': "खाता नहीं है? पंजीकरण करें",
      'alreadyHaveAccountLogin': "पहले से खाता है? लॉगिन करें",
      'backToHome': "होम पर वापस जाएं",
      'unableRequestOtp': "अभी पासवर्ड रीसेट का अनुरोध नहीं किया जा सकता.",
      'enterOtpPrompt': "अपने ईमेल पर भेजा गया 6 अंकों का OTP दर्ज करें.",
      'invalidExpiredOtp': "OTP अमान्य है या इसकी समय सीमा समाप्त हो गई है.",
      'otpUnavailable': "OTP सत्यापित नहीं हो सका.",
      'passwordMinLength': "नए पासवर्ड में कम से कम 8 अक्षर होने चाहिए.",
      'passwordResetFailed': "पासवर्ड रीसेट विफल हुआ। नया OTP मांगें.",
      'customerLoginInvalidSession': "ग्राहक लॉगिन सत्र अमान्य है.",
      'authenticationFailed': "प्रमाणीकरण विफल हुआ",
      'paymentStatusLine': "भुगतान: {method} · {status}",
      'paymentMatchedNotificationHint':
          "दुकान के डिवाइस की सूचना से मिलान किया गया। यह भुगतान प्रदाता की पुष्टि नहीं है; मिलान के लिए UPI संदर्भ सुरक्षित रखें।",
      'paymentPendingHint':
          "भुगतान का मिलान अभी लंबित है। UPI ऐप से वापस आने भर से यह ऑर्डर भुगतान किया हुआ नहीं माना जाता।",
      'paymentStatusPaid': "भुगतान हो गया",
      'paymentStatusPending': "लंबित",
      'paymentStatusCodDue': "नकद भुगतान बाकी",
      'paymentStatusFailed': "विफल",
      'paymentStatusRefund': "वापस किया गया",
      'paymentStatusPartial': "आंशिक भुगतान",
      'expenses': "खर्च",
      'workers': "कर्मचारी",
      'backup': "बैकअप और पुनर्स्थापना",
    },
    'ta': {
      'appTitle': 'சில்லறை மனம்',
      'usernameOrEmail': 'பயனர் பெயர் அல்லது மின்னஞ்சல்',
      'easyBilling': 'எளிய பில்லிங்',
      'betterProfits': 'மேம்பட்ட லாபம்',
      'signInGuidance': 'உள்நுழைவு வழிகாட்டுதலைக் கேளுங்கள்',
      'voiceInstructionsLanguage':
          'உங்கள் மொழியில் குரல் வழிமுறைகளைப் பெறுங்கள்',
      'playVoiceGuidance': 'வழிகாட்டுதலைக் கேளுங்கள்',
      'stopVoiceGuidance': 'பேசுவதை நிறுத்து',
      'continueWithGoogle': 'Google மூலம் தொடரவும்',
      'noAccount': 'கணக்கு இல்லையா?',
      'listenRegisterGuidance': 'பதிவு வழிகாட்டுதலைக் கேளுங்கள்',
      'dataProtected': 'உங்கள் தரவு பாதுகாக்கப்படுகிறது',
      'secureAndSafe': 'பாதுகாப்பானது',
      'growBusinessInLanguage':
          'உங்கள் மொழியில்\nஉங்கள் வணிகத்தை வளர்த்திடுங்கள்',
      'or': 'அல்லது',
      'signingIn': 'உள்நுழைகிறது',
      'verifyingAccount': 'உங்கள் கணக்கு சரிபார்க்கப்படுகிறது...',
      'creatingAccount': 'உங்கள் கணக்கு உருவாக்கப்படுகிறது',
      'registeringShopSync':
          'உங்கள் கடை பாதுகாப்பாகப் பதிவு செய்யப்பட்டு பின்தளத்துடன் ஒத்திசைக்கப்படுகிறது',
      'tagline': 'ஸ்மார்ட் பகுப்பாய்வு மற்றும் பிலிங் பலேடாம்',
      'email': 'மின்னஞ்சல்',
      'password': 'கடவுச்சொல்',
      'login': 'உள்நுழைக',
      'register': 'பதிவு',
      'signIn': 'உள்நுழைக',
      'createAccount': 'புதிய கணக்கை உருவாக்கு',
      'signUp': 'பதிவு செய்',
      'enterEmail': 'உங்கள் மின்னஞ்சலை உள்ளிடவும்',
      'enterPassword': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்',
      'confirmPassword': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      'userName': 'பயனர் பெயர்',
      'shopName': 'கடை பெயர்',
      'location': 'இருப்பிடம்',
      'invalidCredentials': 'தவறான நற்சான்றுகள்',
      'connectionError': 'இணைப்பு பிழை',
      'welcome': 'திரும்பி வரவேற்கிறோம்',
      'enterCredentials': 'தொடர உங்கள் நற்சான்றுகளை உள்ளிடவும்',
      'dashboard': 'டாஷ்போர்டு',
      'sales': 'விற்பனை',
      'query': 'வினவு',
      'giftCard': 'பரிசு அட்டை',
      'bills': 'ஆவணை',
      'insights': 'நுண்ணறிவு',
      'settings': 'அமைப்புகள்',
      'logout': 'வெளியேறு',
      'language': 'மொழி',
      'selectLanguage': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'darkMode': 'இருண்ட பயன்முறை',
      'notification': 'அறிவிப்புகள்',
      'about': 'பற்றி',
      'share': 'பகிரவும்',
      'help': 'உதவி',
      'profile': 'சுயவிவரம்',
      'forgotPassword': 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?',
      'welcomeBack': 'மீண்டும் வருக,',
      'salesByMonth': 'மாதாந்திர விற்பனை',
      'salesByWeek': 'வாராந்திர விற்பனை',
      'salesByYear': 'வருடாந்திர விற்பனை',
      'searchQuery': 'தேடல் வினவல்',
      'dataUpload': 'தரவு பதிவேற்றம்',
      'addSale': 'விற்பனையைச் சேர்க்கவும்',
      'totalAmount': 'மொத்த தொகை',
      'recordedSuccess': 'வெற்றிகரமாக பதிவு செய்யப்பட்டது!',
      'recordedLocally': 'உள்ளூர் சேமிக்கப்பட்டது!',
      'askMeAnything': 'என்னிடம் எதையும் கேளுங்கள்...',
      'aiAssistant': 'AI உதவியாளர்',
      'alwaysHere': 'எப்போதும் உதவ இங்கே உள்ளது',
      'performanceOverview': 'செயல்திறன் மேலோட்டம்',
      'transactions': 'பரிவர்த்தனைகள்',
      'avgOrder': 'சராசரி ஆர்டர்',
      'products': 'தயாரிப்புகள்',
      'quickActions': 'விரைவான செயல்கள்',
      'getInsights': 'நுண்ணறிவுகளைப் பெறுங்கள்',
      'today': 'இன்று',
      'week': 'வாரம்',
      'month': 'மாதம்',
      'year': 'ஆண்டு',
      'showing': 'காட்டுகிறது',
      'phone': 'தொலைபேசி',
      'owner': 'உரிமையாளர்',
      'website': 'இணையதளம்',
      'shopkeeper': 'கடைக்காரர்',
      'shareCard': 'அட்டையைப் பகிரவும்',
      'viewBack': 'பின்புறத்தைப் பார்க்கவும்',
      'viewFront': 'முன்புறத்தைப் பார்க்கவும்',
      'goToDashboard': 'டாஷ்போர்டிற்குச் செல்லவும்',
      'tapToFlip': 'QR குறியீட்டிற்குத் தட்டவும்',
      'tapToSeeFront': 'முன்புறத்தைப் பார்க்கத் தட்டவும்',
      'scanToConnect': 'இணைக்க ஸ்கேன் செய்யவும்',
      'orScan': 'அல்லது ஸ்கேன் செய்யவும்',
      'allContactIncluded': 'அனைத்து தொடர்பு தகவல்களும் சேர்க்கப்பட்டுள்ளன',
      'personalInfo': 'தனிப்பட்ட தகவல்',
      'shopDetails': 'கடை விவரங்கள்',
      'security': 'பாதுகாப்பு',
      'fullName': 'முழு பெயர்',
      'emailAddress': 'மின்னஞ்சல் முகவரி',
      'phoneNumber': 'தொலைபேசி எண்',
      'shopType': 'கடை வகை',
      'taglineOptional': 'டேக்லைன் (விருப்பத்தேர்வு)',
      'websiteOptional': 'இணையதளம் (விருப்பத்தேர்வு)',
      'alreadyHaveAccount': 'ஏற்கனவே கணக்கு உள்ளதா?',
      'joinCommunity': 'எங்கள் சமூகத்தில் இணையுங்கள்',
      'uploadData': 'தரவைப் பதிவேற்றவும்',
      'analytics': 'பகுப்பாய்வு',
      'inventory': 'சரக்கு',
      'reports': 'அறிக்கைகள்',
      'last7Days': 'கடந்த 7 நாட்கள்',
      'last30Days': 'கடந்த 30 நாட்கள்',
      'thisYear': 'இந்த ஆண்டு',
      'noInsights': 'நுண்ணறிவுகள் எதுவும் இல்லை',
      'goodMorning': 'காலை வணக்கம்! ☀️',
      'synced': 'ஒத்திசைக்கப்பட்டது',
      'performanceMessage':
          'உங்கள் கடை இன்று எப்படி செயல்படுகிறது என்பது இங்கே',
      'refresh': 'புதுப்பிப்பதற்கான',
      'salesTrend': 'விற்பனை போக்கு',
      'revenueDistribution': 'வருவாய் விநியோகம்',
      'quantityDistribution': 'அளவு விநியோகம்',
      'revenueLeaders': 'வருவாய் தலைவர்கள்',
      'whatChartShows': 'இந்த விளக்கப்படம் என்ன காட்டுகிறது?',
      'askSimpleLanguage': 'எளிய மொழியில் கேளுங்கள்',
      'askQuestionHint':
          'உதாரணமாக "கடந்த வார விற்பனையைக் காட்டு" போன்ற ஒரு கேள்வியைக் கேளுங்கள்',
      'askButton': 'கேளுங்கள்',
      'queryTip': 'குறிப்பு: உங்கள் தரவுத்தளத்தை வினவ கோப்பை காலியாக விடவும்',
      'responseHint': 'பதில் இங்கே தோன்றும்',
      'enterProductDetails': 'தயாரிப்பு விவரங்களை கீழே உள்ளிடவும்',
      'addProduct': 'தயாரிப்பைச் சேர்க்கவும்',
      'generateBill': 'பில் உருவாக்கவும்',
      'saveSales': 'விற்பனையைச் சேமிக்கவும்',
      'paymentMethod': 'கட்டண முறை',
      'cashOffline': 'ரொக்கம் / ஆஃப்லைன்',
      'onlineUPI': 'ஆன்லைன் / UPI',
      'confirmPayment': 'கட்டணம் பெறப்பட்டதை உறுதிப்படுத்தவும்',
      'paymentConfirmed': 'கட்டணம் உறுதிப்படுத்தப்பட்டது',
      'noSalesData': 'விற்பனை தரவு எதுவும் இல்லை',
      'uploadInventory': 'சரக்குப்பட்டியலைப் பதிவேற்றவும்',
      'selectFile': 'கோப்பைத் தேர்ந்தெடுக்கவும்',
      'upload': 'பதிவேற்றவும்',
      'analyticsOverview': 'பகுப்பாய்வு கண்ணோட்டம்',
      'askToScan':
          'ஸ்கேன் செய்து பணத்தைச் செலுத்துமாறு வாடிக்கையாளரைக் கேட்கவும்',
      'scannedBillTitle': 'ஸ்கேன் செய்யப்பட்ட பில்',
      'askYourQuestion': 'உங்கள் கேள்வியைக் கேளுங்கள்',
      'analysisResults': 'பகுப்பாய்வு முடிவுகள்',
      'analysisSummary': 'பகுப்பாய்வு சுருக்கம்',
      'detailedData': 'விரிவான தரவு',
      'total': 'மொத்தம்',
      'revenueShare': 'வருவாய் பங்கு',
      'topProductsByRevenue': 'வருவாய் அடிப்படையில் சிறந்த தயாரிப்புகள்',
      'volumeAnalysis': 'அளவு பகுப்பாய்வு',
      'unitMovementRadar': 'யூனிட் இயக்கம் ராடார்',
      'upwardTrend': 'வளர்ச்சி போக்கு',
      'downwardTrend': 'வீழ்ச்சி போக்கு',
      'avgChange': 'சராசரி மாற்றம்',
      'noProductData': 'தயாரிப்பு தரவு இல்லை',
      'volumeByProduct': 'பொருளின் அடிப்படையில் அளவு',
      'revenueLeadersDesc':
          'இந்த பார் சார்ட் தேர்ந்தெடுக்கப்பட்ட காலக்கெடுவுக்குள் வருவாய் அடிப்படையில் சிறந்த தயாரிப்புகளை எடுத்துக்காட்டுகிறது.',
      'salesTrendDesc':
          'லைன் சார்ட் சமீபத்திய நாட்களில் மொத்த விற்பனையைக் காட்டுகிறது, இது உங்கள் கடையின் வேகத்தைப் பற்றிய கருத்தை வழங்குகிறது.',
      'revenueDistributionDesc':
          'பை (டோனட்) சார்ட் ஒவ்வொரு தயாரிப்பும் ஒட்டுமொத்த வருவாய்க்கு எவ்வளவு பங்களிக்கிறது என்பதைக் காட்டுகிறது.',
      'quantityDistributionDesc':
          'ராடார் சார்ட் தயாரிப்பிற்கு விற்கப்பட்ட யூனிட்டுகளை ஒப்பிட்டுப் பார்க்கிறது, இது அதிக-விற்பனையாகும் பொருட்களைக் கண்டறிய உதவுகிறது.',
      'monthlySalesDesc':
          'ஒவ்வொரு மாதமும் உங்கள் மொத்த விற்பனைத் தொகையைக் கண்காணிக்கவும். ஆண்டு முழுவதும் போக்குகள் மற்றும் அதிக விற்பனை காலங்களை அடையாளம் காணவும்.',
      'weeklySalesDesc':
          'கடந்த 12 வாரங்களில் உங்கள் விற்பனைச் செயல்திறனைப் பார்க்கவும். வாராந்திர வடிவங்கள் மற்றும் வாரம்-வார வளர்ச்சியை அடையாளம் காணவும்.',
      'yearlySalesDesc':
          'வெவ்வேறு ஆண்டுகளில் மொத்த விற்பனையை ஒப்பிட்டுப் பாருங்கள். நீண்ட கால வணிக வளர்ச்சி மற்றும் செயல்திறன் போக்குகளைக் கண்காணிக்க சரியானதல்ல.',
      'howToUseTitle': 'AI ஷாப் புரோவை எவ்வாறு பயன்படுத்துவது',
      'step1Title': '1. விற்பனையைச் சேர்க்கவும்',
      'step1Desc':
          'விற்பனைச் சேர்க்கும் ஐகானைப் பயன்படுத்தி ஒவ்வொரு விற்பனையையும் பதிவு செய்யுங்கள்.',
      'step2Title': '2. சரக்கு மேலாண்மை',
      'step2Desc':
          'சரக்குத் திரையைப் பயன்படுத்தித் தயாரிப்புகளைக் கண்காணியுங்கள்.',
      'step3Title': '3. அறிக்கைகளைப் பார்க்கவும்',
      'step3Desc':
          'ஆழ்ந்த பகுப்பாய்விற்கு அறிக்கைகள் பகுதியைச் சரிபார்க்கவும்.',
      'step4Title': '4. பரிசு அட்டையைப் பகிரவும்',
      'step4Desc':
          'உங்கள் டிஜிட்டல் பரிசு அட்டையை வாடிக்கையாளர்களுக்கு அனுப்புங்கள்.',
      'step5Title': '5. கொடுப்பனவுகளை ஏற்கவும்',
      'step5Desc':
          'கொடுப்பனவுகளை எளிதாகப் பெற உங்கள் தனிப்பயன் QR ஐக் காட்டுங்கள்.',
      'gotIt': 'புரிந்தது!',
      'dailyPerformanceRating': 'தினசரி செயல்திறன் மதிப்பீடு',
      'salesIncreasedBy': 'இன்றைய விற்பனை அதிகரித்துள்ளது',
      'salesDecreasedBy': 'இன்றைய விற்பனை குறைந்துள்ளது',
      'bestHour': 'சிறந்த நேரம்',
      'yesterdayBestProduct': 'நேற்றைய சிறந்த தயாரிப்பு:',
      'noSales': 'விற்பனை இல்லை',
      'notAvailable': 'கிடைக்கவில்லை',
      'todaySales': 'இன்றைய விற்பனை',
      'yesterdaySales': 'நேற்றைய விற்பனை',
      'analysisAmazing':
          'அற்புதம்! இன்று நீங்கள் ₹{0} சம்பாதித்துள்ளீர்கள், இது நேற்றை விட ₹{1} அதிகம்!',
      'analysisProgressing':
          'முன்னேறுகிறது! இன்றைய விற்பனை ₹{0}. நேற்றைய விற்பனையை விட நீங்கள் வெறும் ₹{1} குறைவாக உள்ளீர்கள்!',
      'analysisWaiting':
          'இன்றைய முதல் விற்பனைக்காகக் காத்திருக்கிறோம். இதைச் சிறந்ததாக மாற்றுவோம்!',
      'analysisMatch':
          'இன்றைய செயல்திறன் நேற்றைய ₹{0} விற்பனையுடன் சரியாக ஒத்துப்போகிறது! தொடர்ச்சியான நிலைத்தன்மை.',
      'goodMorningName': 'காலை வணக்கம், {0}! ☀️',
      'goodAfternoonName': 'மதிய வணக்கம், {0}! 🌤️',
      'goodEveningName': 'இனிய மாலை, {0}! 🌙',
      'tapToUploadQr': 'QR ஐப் பதிவேற்ற தட்டவும்',
      'qrUploadFormat': 'கேலரியில் இருந்து PNG / JPG',
      'tripleChannelActive': 'மூன்று வழி கண்டறிதல் செயலில் உள்ளது',
      'listeningForPayments': 'UPI, SMS மற்றும் திரையை கவனிக்கிறது...',
      'selectDueDate': 'பணம் செலுத்தும் காலக்கெடுவைத் தேர்ந்தெடுக்கவும்',
      'deadline': 'காலக்கெடு',
      'overdue': 'தாமதமானது',
      'pendingPayment': 'நிலுவையில் உள்ள தொகை',
      'setDeadline': 'காலக்கெடுவை நிர்ணயிக்கவும்',
      'attendance': 'வருகை',
      'customers': 'வாடிக்கையாளர்கள்',
      'addCustomer': 'வாடிக்கையாளரைச் சேர்க்கவும்',
      'customerName': 'வாடிக்கையாளர் பெயர்',
      'invoices': 'இன்வாய்ஸ்கள்',
      'newInvoice': 'புதிய இன்வாய்ஸ்',
      'noInvoicesFound': 'இன்வாய்ஸ்கள் எதுவும் இல்லை',
      'noCustomersYet': 'இன்னும் வாடிக்கையாளர்கள் இல்லை',
      'noProductsYet': 'இன்னும் தயாரிப்புகள் இல்லை',
      'checkIn': 'உள்நுழைக',
      'checkOut': 'வெளியேறு',
      'todayStatus': "இன்றைய நிலை",
      'history': 'வரலாறு',
      'viewAll': 'அனைத்தையும் பார்க்கவும்',
      'mrp': 'Mrp',
      'rate': 'விகிதம்',
      'qty': 'அளவு',
      'amt': 'தொகை',
      'description': 'விளக்கம்',
      'billNo': 'பில் எண்',
      'date': 'தேதி',
      'time': 'நேரம்',
      'cashier': 'காசாளர்',
      'counter': 'கவுண்டர்',
      'cashBill': 'ரொக்கப் பில்',
      'youHaveSaved': 'நீங்கள் சேமித்தவை',
      'thankYouVisitAgain': 'நன்றி - மீண்டும் வருக',
      'items': 'பொருட்கள்',
      'cash': 'ரொக்கம்',
      'serve': 'சேவை',
      'discount': 'தள்ளுபடி',
      'username': "பயனர் பெயர்",
      'chooseUsername': "பயனர் பெயரைத் தேர்ந்தெடுக்கவும்",
      'shopDisplayName': "உங்கள் கடையின் காட்சி பெயர்",
      'optional': "விருப்பத்தேர்வு",
      'secure': "பாதுகாப்பானது",
      'resetCustomerPassword': "வாடிக்கையாளர் கடவுச்சொல்லை மீட்டமைக்கவும்",
      'accountEmail': "கணக்கு மின்னஞ்சல்",
      'sendOtp': "OTP அனுப்பவும்",
      'cancel': "ரத்துசெய்",
      'enterVerificationCode': "சரிபார்ப்புக் குறியீட்டை உள்ளிடவும்",
      'otpSixDigits': "6 இலக்க OTP",
      'verify': "சரிபார்க்கவும்",
      'chooseNewPassword': "புதிய கடவுச்சொல்லைத் தேர்ந்தெடுக்கவும்",
      'newPasswordAtLeast8': "புதிய கடவுச்சொல் (குறைந்தது 8 எழுத்துகள்)",
      'updatePassword': "கடவுச்சொல்லைப் புதுப்பிக்கவும்",
      'passwordUpdatedLogin':
          "கடவுச்சொல் புதுப்பிக்கப்பட்டது. புதிய கடவுச்சொல்லுடன் உள்நுழையவும்.",
      'registrationSuccessLogin': "பதிவு வெற்றிகரமானது! உள்நுழையவும்.",
      'welcomeBackShopper': "மீண்டும் வரவேற்கிறோம்!",
      'createYourAccount': "உங்கள் கணக்கை உருவாக்கவும்",
      'phoneTenDigits': "தொலைபேசி (10 இலக்கங்கள்)",
      'needAccountRegister': "கணக்கு இல்லையா? பதிவு செய்யவும்",
      'alreadyHaveAccountLogin': "ஏற்கனவே கணக்கு உள்ளதா? உள்நுழையவும்",
      'backToHome': "முகப்புக்குத் திரும்பு",
      'unableRequestOtp': "இப்போது கடவுச்சொல் மீட்டமைப்பைக் கோர முடியவில்லை.",
      'enterOtpPrompt':
          "உங்கள் மின்னஞ்சலுக்கு அனுப்பப்பட்ட 6 இலக்க OTP-ஐ உள்ளிடவும்.",
      'invalidExpiredOtp': "OTP தவறானது அல்லது காலாவதியானது.",
      'otpUnavailable': "OTP-ஐ சரிபார்க்க முடியவில்லை.",
      'passwordMinLength':
          "புதிய கடவுச்சொல்லில் குறைந்தது 8 எழுத்துகள் இருக்க வேண்டும்.",
      'passwordResetFailed':
          "கடவுச்சொல் மீட்டமைப்பு தோல்வியடைந்தது. புதிய OTP-ஐ கோரவும்.",
      'customerLoginInvalidSession': "வாடிக்கையாளர் உள்நுழைவு அமர்வு தவறானது.",
      'authenticationFailed': "அங்கீகாரம் தோல்வியடைந்தது",
      'paymentStatusLine': "கட்டணம்: {method} · {status}",
      'paymentMatchedNotificationHint':
          "கடைச் சாதன அறிவிப்புடன் பொருத்தப்பட்டது. இது கட்டண வழங்குநரின் உறுதிப்படுத்தல் அல்ல; சரிபார்ப்பிற்காக UPI குறிப்பு எண்ணை வைத்திருக்கவும்.",
      'paymentPendingHint':
          "கட்டணப் பொருத்த உறுதிப்படுத்தல் இன்னும் நிலுவையில் உள்ளது. UPI செயலியிலிருந்து திரும்புவது மட்டும் இந்த ஆர்டர் செலுத்தப்பட்டதாகக் குறிக்காது.",
      'paymentStatusPaid': "செலுத்தப்பட்டது",
      'paymentStatusPending': "நிலுவையில் உள்ளது",
      'paymentStatusCodDue': "ரொக்கப் பணம் நிலுவை",
      'paymentStatusFailed': "தோல்வி",
      'paymentStatusRefund': "திருப்பிச் செலுத்தப்பட்டது",
      'paymentStatusPartial': "பகுதி கட்டணம்",
      'expenses': "செலவுகள்",
      'workers': "பணியாளர்கள்",
      'backup': "காப்புப்பிரதி மற்றும் மீட்டமைப்பு",
    },
    'kn': {
      'username': "ಬಳಕೆದಾರ ಹೆಸರು",
      'chooseUsername': "ಬಳಕೆದಾರ ಹೆಸರನ್ನು ಆಯ್ಕೆಮಾಡಿ",
      'shopDisplayName': "ನಿಮ್ಮ ಅಂಗಡಿಯ ಪ್ರದರ್ಶನ ಹೆಸರು",
      'optional': "ಐಚ್ಛಿಕ",
      'secure': "ಸುರಕ್ಷಿತ",
      'resetCustomerPassword': "ಗ್ರಾಹಕರ ಪಾಸ್‌ವರ್ಡ್ ಮರುಹೊಂದಿಸಿ",
      'accountEmail': "ಖಾತೆಯ ಇಮೇಲ್",
      'sendOtp': "OTP ಕಳುಹಿಸಿ",
      'cancel': "ರದ್ದುಮಾಡಿ",
      'enterVerificationCode': "ಪರಿಶೀಲನಾ ಕೋಡ್ ನಮೂದಿಸಿ",
      'otpSixDigits': "6 ಅಂಕಿಯ OTP",
      'verify': "ಪರಿಶೀಲಿಸಿ",
      'chooseNewPassword': "ಹೊಸ ಪಾಸ್‌ವರ್ಡ್ ಆಯ್ಕೆಮಾಡಿ",
      'newPasswordAtLeast8': "ಹೊಸ ಪಾಸ್‌ವರ್ಡ್ (ಕನಿಷ್ಠ 8 ಅಕ್ಷರಗಳು)",
      'updatePassword': "ಪಾಸ್‌ವರ್ಡ್ ನವೀಕರಿಸಿ",
      'passwordUpdatedLogin':
          "ಪಾಸ್‌ವರ್ಡ್ ನವೀಕರಿಸಲಾಗಿದೆ. ಹೊಸ ಪಾಸ್‌ವರ್ಡ್‌ನಿಂದ ಲಾಗಿನ್ ಮಾಡಿ.",
      'registrationSuccessLogin': "ನೋಂದಣಿ ಯಶಸ್ವಿಯಾಗಿದೆ! ದಯವಿಟ್ಟು ಲಾಗಿನ್ ಮಾಡಿ.",
      'welcomeBackShopper': "ಮತ್ತೆ ಸ್ವಾಗತ!",
      'createYourAccount': "ನಿಮ್ಮ ಖಾತೆ ರಚಿಸಿ",
      'phoneTenDigits': "ಫೋನ್ (10 ಅಂಕಿಗಳು)",
      'needAccountRegister': "ಖಾತೆ ಇಲ್ಲವೇ? ನೋಂದಾಯಿಸಿ",
      'alreadyHaveAccountLogin': "ಈಗಾಗಲೇ ಖಾತೆಯಿದೆಯೇ? ಲಾಗಿನ್ ಮಾಡಿ",
      'backToHome': "ಮುಖಪುಟಕ್ಕೆ ಹಿಂತಿರುಗಿ",
      'unableRequestOtp': "ಈಗ ಪಾಸ್‌ವರ್ಡ್ ಮರುಹೊಂದಿಕೆ ವಿನಂತಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ.",
      'enterOtpPrompt': "ನಿಮ್ಮ ಇಮೇಲ್‌ಗೆ ಕಳುಹಿಸಿದ 6 ಅಂಕಿಯ OTP ನಮೂದಿಸಿ.",
      'invalidExpiredOtp': "OTP ಅಮಾನ್ಯವಾಗಿದೆ ಅಥವಾ ಅವಧಿ ಮೀರಿದೆ.",
      'otpUnavailable': "OTP ಪರಿಶೀಲಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.",
      'passwordMinLength': "ಹೊಸ ಪಾಸ್‌ವರ್ಡ್ ಕನಿಷ್ಠ 8 ಅಕ್ಷರಗಳಿರಬೇಕು.",
      'passwordResetFailed': "ಪಾಸ್‌ವರ್ಡ್ ಮರುಹೊಂದಿಕೆ ವಿಫಲವಾಗಿದೆ. ಹೊಸ OTP ಕೇಳಿ.",
      'customerLoginInvalidSession': "ಗ್ರಾಹಕರ ಲಾಗಿನ್ ಸೆಷನ್ ಅಮಾನ್ಯವಾಗಿದೆ.",
      'authenticationFailed': "ದೃಢೀಕರಣ ವಿಫಲವಾಗಿದೆ",
      'paymentStatusLine': "ಪಾವತಿ: {method} · {status}",
      'paymentMatchedNotificationHint':
          "ಅಂಗಡಿಯ ಸಾಧನದ ಅಧಿಸೂಚನೆಯೊಂದಿಗೆ ಹೊಂದಿಸಲಾಗಿದೆ. ಇದು ಪಾವತಿ ಪೂರೈಕೆದಾರರ ದೃಢೀಕರಣವಲ್ಲ; ಹೊಂದಾಣಿಕೆಗಾಗಿ UPI ಉಲ್ಲೇಖವನ್ನು ಉಳಿಸಿಕೊಳ್ಳಿ.",
      'paymentPendingHint':
          "ಪಾವತಿ ಹೊಂದಾಣಿಕೆಯ ದೃಢೀಕರಣ ಇನ್ನೂ ಬಾಕಿಯಿದೆ. UPI ಆ್ಯಪ್‌ನಿಂದ ಮರಳುವುದರಿಂದ ಮಾತ್ರ ಈ ಆರ್ಡರ್ ಪಾವತಿಯಾದಂತಾಗುವುದಿಲ್ಲ.",
      'paymentStatusPaid': "ಪಾವತಿಸಲಾಗಿದೆ",
      'paymentStatusPending': "ಬಾಕಿಯಿದೆ",
      'paymentStatusCodDue': "ನಗದು ಬಾಕಿ",
      'paymentStatusFailed': "ವಿಫಲವಾಗಿದೆ",
      'paymentStatusRefund': "ಮರುಪಾವತಿಸಲಾಗಿದೆ",
      'paymentStatusPartial': "ಭಾಗಶಃ ಪಾವತಿ",
      'appTitle': "ರಿಟೇಲ್ ಮೈಂಡ್",
      'usernameOrEmail': 'ಬಳಕೆದಾರ ಹೆಸರು ಅಥವಾ ಇಮೇಲ್',
      'easyBilling': 'ಸುಲಭ ಬಿಲ್ಲಿಂಗ್',
      'betterProfits': 'ಹೆಚ್ಚಿನ ಲಾಭ',
      'signInGuidance': 'ಸೈನ್-ಇನ್ ಮಾರ್ಗದರ್ಶನವನ್ನು ಆಲಿಸಿ',
      'voiceInstructionsLanguage': 'ನಿಮ್ಮ ಭಾಷೆಯಲ್ಲಿ ಧ್ವನಿ ಸೂಚನೆಗಳನ್ನು ಪಡೆಯಿರಿ',
      'playVoiceGuidance': 'ಮಾರ್ಗದರ್ಶನವನ್ನು ಆಲಿಸಿ',
      'stopVoiceGuidance': 'ಮಾತನಾಡುವುದನ್ನು ನಿಲ್ಲಿಸಿ',
      'continueWithGoogle': 'Google ಮೂಲಕ ಮುಂದುವರಿಸಿ',
      'noAccount': 'ಖಾತೆ ಇಲ್ಲವೇ?',
      'listenRegisterGuidance': 'ನೋಂದಣಿ ಮಾರ್ಗದರ್ಶನವನ್ನು ಆಲಿಸಿ',
      'dataProtected': 'ನಿಮ್ಮ ಡೇಟಾ ಸುರಕ್ಷಿತವಾಗಿದೆ',
      'secureAndSafe': 'ಸುರಕ್ಷಿತ ಮತ್ತು ಭದ್ರ',
      'growBusinessInLanguage': 'ನಿಮ್ಮ ಭಾಷೆಯಲ್ಲಿ\nನಿಮ್ಮ ವ್ಯಾಪಾರವನ್ನು ಬೆಳೆಸಿ',
      'or': 'ಅಥವಾ',
      'signingIn': 'ಸೈನ್ ಇನ್ ಆಗುತ್ತಿದೆ',
      'verifyingAccount': 'ನಿಮ್ಮ ಖಾತೆಯನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ...',
      'creatingAccount': 'ನಿಮ್ಮ ಖಾತೆಯನ್ನು ರಚಿಸಲಾಗುತ್ತಿದೆ',
      'registeringShopSync':
          'ನಿಮ್ಮ ಅಂಗಡಿಯನ್ನು ಸುರಕ್ಷಿತವಾಗಿ ನೋಂದಾಯಿಸಿ ಬ್ಯಾಕೆಂಡ್‌ನೊಂದಿಗೆ ಸಿಂಕ್ ಮಾಡಲಾಗುತ್ತಿದೆ',
      'tagline': "ಸ್ಮಾರ್ಟ್ ವಿಶ್ಲೇಷಣೆ ಮತ್ತು ಬಿಲ್ಲಿಂಗ್ ವೇದಿಕೆ",
      'email': "ಇಮೇಲ್",
      'password': "ಪಾಸ್‌ವರ್ಡ್",
      'login': "ಲಾಗಿನ್",
      'register': "ನೋಂದಣಿ",
      'signIn': "ಸೈನ್ ಇನ್",
      'createAccount': "ಹೊಸ ಖಾತೆ ರಚಿಸಿ",
      'signUp': "ಸೈನ್ ಅಪ್",
      'enterEmail': "ನಿಮ್ಮ ಇಮೇಲ್ ನಮೂದಿಸಿ",
      'enterPassword': "ನಿಮ್ಮ ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ",
      'confirmPassword': "ಪಾಸ್‌ವರ್ಡ್ ದೃಢೀಕರಿಸಿ",
      'userName': "ಬಳಕೆದಾರ ಹೆಸರು",
      'shopName': "ಅಂಗಡಿ ಹೆಸರು",
      'invalidCredentials': "ಅಮಾನ್ಯ ವಿವರಗಳು",
      'connectionError': "ಸಂಪರ್ಕ ದೋಷ",
      'welcome': "ಮತ್ತೆ ಸ್ವಾಗತ",
      'enterCredentials': "ಮುಂದುವರಿಯಲು ನಿಮ್ಮ ವಿವರಗಳನ್ನು ನಮೂದಿಸಿ",
      'dashboard': "ಡ್ಯಾಶ್‌ಬೋರ್ಡ್",
      'sales': "ಮಾರಾಟ",
      'bills': "ಬಿಲ್‌ಗಳು",
      'settings': "ಸೆಟ್ಟಿಂಗ್‌ಗಳು",
      'logout': "ಲಾಗ್ ಔಟ್",
      'language': "ಭಾಷೆ",
      'selectLanguage': "ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ",
      'forgotPassword': "ಪಾಸ್‌ವರ್ಡ್ ಮರೆತಿರುವಿರಾ?",
      'welcomeBack': "ಮತ್ತೆ ಸ್ವಾಗತ",
      'phone': "ಫೋನ್",
      'owner': "ಮಾಲೀಕರು",
      'profile': "ಪ್ರೊಫೈಲ್",
      'fullName': "ಪೂರ್ಣ ಹೆಸರು",
      'emailAddress': "ಇಮೇಲ್ ವಿಳಾಸ",
      'phoneNumber': "ಫೋನ್ ಸಂಖ್ಯೆ",
      'alreadyHaveAccount': "ಈಗಾಗಲೇ ಖಾತೆಯಿದೆಯೇ?",
      'inventory': "ದಾಸ್ತಾನು",
      'reports': "ವರದಿಗಳು",
      'customers': "ಗ್ರಾಹಕರು",
      'invoices': "ಇನ್ವಾಯ್ಸ್‌ಗಳು",
      'total': "ಒಟ್ಟು",
      'refresh': "ರಿಫ್ರೆಶ್",
      'today': "ಇಂದು",
      'salesByMonth': "ತಿಂಗಳ ಮಾರಾಟ",
      'salesByWeek': "ವಾರದ ಮಾರಾಟ",
      'salesByYear': "ವರ್ಷದ ಮಾರಾಟ",
      'searchQuery': "ಹುಡುಕಾಟ ಪ್ರಶ್ನೆ",
      'dataUpload': "ಡೇಟಾ ಅಪ್‌ಲೋಡ್",
      'addSale': "ಮಾರಾಟ ಸೇರಿಸಿ",
      'totalAmount': "ಒಟ್ಟು ಮೊತ್ತ",
      'recordedSuccess': "ಯಶಸ್ವಿಯಾಗಿ ದಾಖಲಿಸಲಾಗಿದೆ!",
      'recordedLocally': "ಸ್ಥಳೀಯವಾಗಿ ಉಳಿಸಲಾಗಿದೆ!",
      'askMeAnything': "ಏನನ್ನಾದರೂ ಕೇಳಿ...",
      'aiAssistant': "AI ಸಹಾಯಕ",
      'performanceOverview': "ಕಾರ್ಯಕ್ಷಮತೆಯ ಅವಲೋಕನ",
      'transactions': "ವಹಿವಾಟುಗಳು",
      'avgOrder': "ಸರಾಸರಿ ಆರ್ಡರ್",
      'products': "ಉತ್ಪನ್ನಗಳು",
      'quickActions': "ತ್ವರಿತ ಕ್ರಿಯೆಗಳು",
      'getInsights': "ಒಳನೋಟಗಳನ್ನು ಪಡೆಯಿರಿ",
      'week': "ವಾರ",
      'month': "ತಿಂಗಳು",
      'year': "ವರ್ಷ",
      'showing': "ತೋರಿಸಲಾಗುತ್ತಿದೆ",
      'website': "ವೆಬ್‌ಸೈಟ್",
      'shopkeeper': "ಅಂಗಡಿಯವರು",
      'shareCard': "ಕಾರ್ಡ್ ಹಂಚಿಕೊಳ್ಳಿ",
      'viewBack': "ಹಿಂಭಾಗ ನೋಡಿ",
      'viewFront': "ಮುಂಭಾಗ ನೋಡಿ",
      'goToDashboard': "ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಹೋಗಿ",
      'scanToConnect': "ಸಂಪರ್ಕಿಸಲು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ",
      'personalInfo': "ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ",
      'shopDetails': "ಅಂಗಡಿ ವಿವರಗಳು",
      'security': "ಭದ್ರತೆ",
      'shopType': "ಅಂಗಡಿ ಪ್ರಕಾರ",
      'taglineOptional': "ಟ್ಯಾಗ್‌ಲೈನ್ (ಐಚ್ಛಿಕ)",
      'websiteOptional': "ವೆಬ್‌ಸೈಟ್ (ಐಚ್ಛಿಕ)",
      'analytics': "ವಿಶ್ಲೇಷಣೆ",
      'last7Days': "ಕಳೆದ 7 ದಿನಗಳು",
      'last30Days': "ಕಳೆದ 30 ದಿನಗಳು",
      'thisYear': "ಈ ವರ್ಷ",
      'noInsights': "ಒಳನೋಟಗಳಿಲ್ಲ",
      'goodMorning': "ಶುಭೋದಯ!",
      'synced': "ಸಿಂಕ್ ಆಗಿದೆ",
      'performanceMessage': "ಇಂದು ನಿಮ್ಮ ಅಂಗಡಿಯ ಕಾರ್ಯಕ್ಷಮತೆ ಇಲ್ಲಿದೆ",
      'salesTrend': "ಮಾರಾಟದ ಪ್ರವೃತ್ತಿ",
      'revenueDistribution': "ಆದಾಯ ಹಂಚಿಕೆ",
      'quantityDistribution': "ಪ್ರಮಾಣ ಹಂಚಿಕೆ",
      'revenueLeaders': "ಹೆಚ್ಚು ಆದಾಯದ ಉತ್ಪನ್ನಗಳು",
      'whatChartShows': "ಈ ಚಾರ್ಟ್ ಏನು ತೋರಿಸುತ್ತದೆ?",
      'askSimpleLanguage': "ಸರಳ ಭಾಷೆಯಲ್ಲಿ ಕೇಳಿ",
      'askButton': "ಕೇಳಿ",
      'enterProductDetails': "ಕೆಳಗೆ ಉತ್ಪನ್ನದ ವಿವರಗಳನ್ನು ನಮೂದಿಸಿ",
      'addProduct': "ಉತ್ಪನ್ನ ಸೇರಿಸಿ",
      'generateBill': "ಬಿಲ್ ರಚಿಸಿ",
      'saveSales': "ಮಾರಾಟ ಉಳಿಸಿ",
      'paymentMethod': "ಪಾವತಿ ವಿಧಾನ",
      'cashOffline': "ನಗದು / ಆಫ್‌ಲೈನ್",
      'onlineUPI': "ಆನ್‌ಲೈನ್ / UPI",
      'confirmPayment': "ಪಾವತಿ ಸ್ವೀಕರಿಸಿದ್ದನ್ನು ದೃಢೀಕರಿಸಿ",
      'paymentConfirmed': "ಪಾವತಿ ದೃಢೀಕರಿಸಲಾಗಿದೆ",
      'noSalesData': "ಮಾರಾಟದ ಮಾಹಿತಿ ಲಭ್ಯವಿಲ್ಲ",
      'uploadInventory': "ದಾಸ್ತಾನು ಅಪ್‌ಲೋಡ್",
      'selectFile': "ಫೈಲ್ ಆಯ್ಕೆಮಾಡಿ",
      'upload': "ಅಪ್‌ಲೋಡ್",
      'analyticsOverview': "ವಿಶ್ಲೇಷಣೆಯ ಅವಲೋಕನ",
      'askToScan': "ಸ್ಕ್ಯಾನ್ ಮಾಡಿ ಪಾವತಿಸಲು ಗ್ರಾಹಕರಿಗೆ ತಿಳಿಸಿ",
      'scannedBillTitle': "ಸ್ಕ್ಯಾನ್ ಮಾಡಿದ ಬಿಲ್",
      'askYourQuestion': "ನಿಮ್ಮ ಪ್ರಶ್ನೆಯನ್ನು ಕೇಳಿ",
      'analysisResults': "ವಿಶ್ಲೇಷಣೆಯ ಫಲಿತಾಂಶಗಳು",
      'analysisSummary': "ವಿಶ್ಲೇಷಣೆಯ ಸಾರಾಂಶ",
      'detailedData': "ವಿವರವಾದ ಡೇಟಾ",
      'revenueShare': "ಆದಾಯದ ಪಾಲು",
      'topProductsByRevenue': "ಆದಾಯದ ಆಧಾರದ ಮೇಲೆ ಪ್ರಮುಖ ಉತ್ಪನ್ನಗಳು",
      'volumeAnalysis': "ಪ್ರಮಾಣ ವಿಶ್ಲೇಷಣೆ",
      'unitMovementRadar': "ಯೂನಿಟ್ ಚಲನೆಯ ರಡಾರ್",
      'upwardTrend': "ಏರಿಕೆಯ ಪ್ರವೃತ್ತಿ",
      'downwardTrend': "ಇಳಿಕೆಯ ಪ್ರವೃತ್ತಿ",
      'noProductData': "ಉತ್ಪನ್ನದ ಡೇಟಾ ಇಲ್ಲ",
      'volumeByProduct': "ಉತ್ಪನ್ನದ ಪ್ರಕಾರ ಪ್ರಮಾಣ",
      'selectDueDate': "ಪಾವತಿ ಕೊನೆಯ ದಿನಾಂಕ ಆಯ್ಕೆಮಾಡಿ",
      'deadline': "ಕೊನೆಯ ದಿನಾಂಕ",
      'overdue': "ಅವಧಿ ಮೀರಿದೆ",
      'pendingPayment': "ಬಾಕಿ ಪಾವತಿ",
      'setDeadline': "ಕೊನೆಯ ದಿನಾಂಕ ಹೊಂದಿಸಿ",
      'attendance': "ಹಾಜರಾತಿ",
      'addCustomer': "ಗ್ರಾಹಕ ಸೇರಿಸಿ",
      'customerName': "ಗ್ರಾಹಕರ ಹೆಸರು",
      'newInvoice': "ಹೊಸ ಇನ್ವಾಯ್ಸ್",
      'noInvoicesFound': "ಇನ್ವಾಯ್ಸ್‌ಗಳು ಕಂಡುಬಂದಿಲ್ಲ",
      'noCustomersYet': "ಇನ್ನೂ ಗ್ರಾಹಕರಿಲ್ಲ",
      'noProductsYet': "ಇನ್ನೂ ಉತ್ಪನ್ನಗಳಿಲ್ಲ",
      'checkIn': "ಚೆಕ್ ಇನ್",
      'checkOut': "ಚೆಕ್ ಔಟ್",
      'todayStatus': "ಇಂದಿನ ಸ್ಥಿತಿ",
      'history': "ಇತಿಹಾಸ",
      'viewAll': "ಎಲ್ಲವನ್ನೂ ನೋಡಿ",
      'mrp': "ಗರಿಷ್ಠ ಚಿಲ್ಲರೆ ಬೆಲೆ",
      'rate': "ದರ",
      'qty': "ಪ್ರಮಾಣ",
      'amt': "ಮೊತ್ತ",
      'description': "ವಿವರಣೆ",
      'billNo': "ಬಿಲ್ ಸಂಖ್ಯೆ",
      'date': "ದಿನಾಂಕ",
      'time': "ಸಮಯ",
      'cashier': "ಕ್ಯಾಷಿಯರ್",
      'counter': "ಕೌಂಟರ್",
      'cashBill': "ನಗದು ಬಿಲ್",
      'youHaveSaved': "ನೀವು ಉಳಿಸಿದ್ದು",
      'thankYouVisitAgain': "ಧನ್ಯವಾದಗಳು - ಮತ್ತೆ ಬನ್ನಿ",
      'items': "ವಸ್ತುಗಳು",
      'cash': "ನಗದು",
      'serve': "ಸೇವೆ",
      'discount': "ರಿಯಾಯಿತಿ",
      'expenses': "ಖರ್ಚುಗಳು",
      'workers': "ಕಾರ್ಮಿಕರು",
      'backup': "ಬ್ಯಾಕಪ್ ಮತ್ತು ಮರುಸ್ಥಾಪನೆ",
      'location': "ಸ್ಥಳ",
      'query': "ಪ್ರಶ್ನೆ",
      'giftCard': "ಉಡುಗೊರೆ ಕಾರ್ಡ್",
      'insights': "ಒಳನೋಟಗಳು",
      'darkMode': "ಡಾರ್ಕ್ ಮೋಡ್",
      'notification': "ಅಧಿಸೂಚನೆಗಳು",
      'about': "ಕುರಿತು",
      'share': "ಹಂಚಿಕೊಳ್ಳಿ",
      'help': "ಸಹಾಯ",
      'alwaysHere': "ಸಹಾಯಕ್ಕೆ ಯಾವಾಗಲೂ ಸಿದ್ಧ",
      'tapToFlip': "QR ಕೋಡ್‌ಗಾಗಿ ತಿರುಗಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ",
      'tapToSeeFront': "ಮುಂಭಾಗ ನೋಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ",
      'orScan': "ಅಥವಾ ಸ್ಕ್ಯಾನ್ ಮಾಡಿ",
      'allContactIncluded': "ಎಲ್ಲ ಸಂಪರ್ಕ ಮಾಹಿತಿ ಸೇರಿಸಲಾಗಿದೆ",
      'joinCommunity': "ನಮ್ಮ ಸಮುದಾಯಕ್ಕೆ ಸೇರಿ",
      'uploadData': "ಡೇಟಾ ಅಪ್‌ಲೋಡ್ ಮಾಡಿ",
      'askQuestionHint': "ಪ್ರಶ್ನೆ ಕೇಳಿ (ಉದಾ: ಕಳೆದ ವಾರದ ಮಾರಾಟ ತೋರಿಸಿ)",
      'queryTip': "ಸಲಹೆ: ಡೇಟಾಬೇಸ್‌ನಲ್ಲಿ ಹುಡುಕಲು ಫೈಲ್ ಖಾಲಿ ಬಿಡಿ",
      'responseHint': "ಉತ್ತರ ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತದೆ",
      'avgChange': "ಸರಾಸರಿ ಬದಲಾವಣೆ",
      'revenueLeadersDesc':
          "ಈ ಬಾರ್ ಚಾರ್ಟ್ ಆಯ್ದ ಅವಧಿಯಲ್ಲಿ ಆದಾಯದ ಪ್ರಕಾರ ಅಗ್ರ ಉತ್ಪನ್ನಗಳನ್ನು ತೋರಿಸುತ್ತದೆ.",
      'salesTrendDesc':
          "ಈ ಲೈನ್ ಚಾರ್ಟ್ ಇತ್ತೀಚಿನ ದಿನಗಳ ಒಟ್ಟು ಮಾರಾಟವನ್ನು ತೋರಿಸಿ ಅಂಗಡಿಯ ಪ್ರಗತಿಯನ್ನು ತಿಳಿಸುತ್ತದೆ.",
      'revenueDistributionDesc':
          "ಈ ಪೈ ಚಾರ್ಟ್ ಒಟ್ಟು ಆದಾಯದಲ್ಲಿ ಪ್ರತಿ ಉತ್ಪನ್ನದ ಪಾಲನ್ನು ತೋರಿಸುತ್ತದೆ.",
      'quantityDistributionDesc':
          "ಈ ರಡಾರ್ ಚಾರ್ಟ್ ಪ್ರತಿ ಉತ್ಪನ್ನದ ಮಾರಾಟವಾದ ಘಟಕಗಳನ್ನು ಹೋಲಿಸುತ್ತದೆ.",
      'monthlySalesDesc':
          "ಪ್ರತಿ ತಿಂಗಳ ಒಟ್ಟು ಮಾರಾಟವನ್ನು ಗಮನಿಸಿ. ವರ್ಷದ ಮಾರಾಟದ ಪ್ರವೃತ್ತಿ ಮತ್ತು ಗರಿಷ್ಠ ಅವಧಿಗಳನ್ನು ಗುರುತಿಸಿ.",
      'weeklySalesDesc':
          "ಕಳೆದ 12 ವಾರಗಳ ಮಾರಾಟ ನೋಡಿ. ವಾರದ ಮಾದರಿ ಮತ್ತು ಬೆಳವಣಿಗೆಯನ್ನು ಗುರುತಿಸಿ.",
      'yearlySalesDesc':
          "ವಿವಿಧ ವರ್ಷಗಳ ಒಟ್ಟು ಮಾರಾಟವನ್ನು ಹೋಲಿಸಿ ದೀರ್ಘಕಾಲದ ಬೆಳವಣಿಗೆಯನ್ನು ನೋಡಿ.",
      'howToUseTitle': "Retail Mind ಬಳಸುವ ವಿಧಾನ",
      'step1Title': "1. ಮಾರಾಟ ಸೇರಿಸಿ",
      'step1Desc': "ಮಾರಾಟ ಸೇರಿಸಿ ಐಕಾನ್ ಬಳಸಿ ಪ್ರತಿ ಮಾರಾಟ ದಾಖಲಿಸಿ.",
      'step2Title': "2. ದಾಸ್ತಾನು ನಿರ್ವಹಿಸಿ",
      'step2Desc': "ದಾಸ್ತಾನು ಪರದೆಯಲ್ಲಿ ಉತ್ಪನ್ನಗಳ ಸಂಗ್ರಹವನ್ನು ಗಮನಿಸಿ.",
      'step3Title': "3. ವರದಿಗಳನ್ನು ನೋಡಿ",
      'step3Desc': "ವಿಸ್ತೃತ ವಿಶ್ಲೇಷಣೆಗೆ ವರದಿಗಳ ವಿಭಾಗ ತೆರೆಯಿರಿ.",
      'step4Title': "4. ಉಡುಗೊರೆ ಕಾರ್ಡ್ ಹಂಚಿಕೊಳ್ಳಿ",
      'step4Desc': "ಡಿಜಿಟಲ್ ಉಡುಗೊರೆ ಕಾರ್ಡ್‌ನ್ನು ಗ್ರಾಹಕರಿಗೆ ಕಳುಹಿಸಿ.",
      'step5Title': "5. ಪಾವತಿಗಳನ್ನು ಸ್ವೀಕರಿಸಿ",
      'step5Desc': "ಪಾವತಿ ಪಡೆಯಲು ನಿಮ್ಮ QR ಕೋಡ್ ತೋರಿಸಿ.",
      'gotIt': "ಅರ್ಥವಾಯಿತು!",
      'dailyPerformanceRating': "ದೈನಂದಿನ ಕಾರ್ಯಕ್ಷಮತೆ ಮೌಲ್ಯಮಾಪನ",
      'salesIncreasedBy': "ಇಂದಿನ ಮಾರಾಟ ಹೆಚ್ಚಾಗಿದೆ",
      'salesDecreasedBy': "ಇಂದಿನ ಮಾರಾಟ ಕಡಿಮೆಯಾಗಿದೆ",
      'bestHour': "ಅತ್ಯುತ್ತಮ ಗಂಟೆ",
      'yesterdayBestProduct': "ನಿನ್ನೆ ಹೆಚ್ಚು ಮಾರಾಟವಾದ ಉತ್ಪನ್ನ:",
      'noSales': "ಮಾರಾಟವಿಲ್ಲ",
      'notAvailable': "ಲಭ್ಯವಿಲ್ಲ",
      'todaySales': "ಇಂದಿನ ಮಾರಾಟ",
      'yesterdaySales': "ನಿನ್ನೆಯ ಮಾರಾಟ",
      'analysisAmazing':
          "ಅದ್ಭುತ! ಇಂದು ನೀವು ₹{0} ಗಳಿಸಿದ್ದೀರಿ; ಇದು ನಿನ್ನೆಗಿಂತ ₹{1} ಹೆಚ್ಚು!",
      'analysisProgressing':
          "ಮಾರಾಟ ಉತ್ತಮವಾಗುತ್ತಿದೆ! ಇಂದು ₹{0} ಮಾರಾಟವಾಗಿದೆ. ನಿನ್ನೆಯ ದಾಖಲೆಯನ್ನು ಮೀರಿಸಲು ₹{1} ಬೇಕು.",
      'analysisWaiting':
          "ಇಂದಿನ ಮೊದಲ ಮಾರಾಟಕ್ಕಾಗಿ ಕಾಯಲಾಗುತ್ತಿದೆ. ದಿನವನ್ನು ಉತ್ತಮವಾಗಿಸೋಣ!",
      'analysisMatch': "ಇಂದಿನ ಮಾರಾಟ ನಿನ್ನೆಯಂತೆಯೇ ₹{0}! ಸ್ಥಿರವಾದ ಪ್ರದರ್ಶನ.",
      'goodMorningName': "ಶುಭೋದಯ, {0}! ☀️",
      'goodAfternoonName': "ಶುಭ ಮಧ್ಯಾಹ್ನ, {0}! 🌤️",
      'goodEveningName': "ಶುಭ ಸಂಜೆ, {0}! 🌙",
      'tapToUploadQr': "QR ಅಪ್‌ಲೋಡ್ ಮಾಡಲು ಟ್ಯಾಪ್ ಮಾಡಿ",
      'qrUploadFormat': "ಗ್ಯಾಲರಿಯಿಂದ PNG / JPG",
      'tripleChannelActive': "ಮೂರು ಚಾನೆಲ್ ಪತ್ತೆ ಸಕ್ರಿಯ",
      'listeningForPayments': "UPI, SMS ಮತ್ತು ಪರದೆಯನ್ನು ಗಮನಿಸಲಾಗುತ್ತಿದೆ...",
    },
    'ml': {
      'username': "ഉപയോക്തൃനാമം",
      'chooseUsername': "ഒരു ഉപയോക്തൃനാമം തിരഞ്ഞെടുക്കുക",
      'shopDisplayName': "നിങ്ങളുടെ കടയുടെ പ്രദർശനനാമം",
      'optional': "ഐച്ഛികം",
      'secure': "സുരക്ഷിതം",
      'resetCustomerPassword': "ഉപഭോക്തൃ പാസ്‌വേഡ് പുനഃസജ്ജമാക്കുക",
      'accountEmail': "അക്കൗണ്ട് ഇമെയിൽ",
      'sendOtp': "OTP അയയ്ക്കുക",
      'cancel': "റദ്ദാക്കുക",
      'enterVerificationCode': "സ്ഥിരീകരണ കോഡ് നൽകുക",
      'otpSixDigits': "6 അക്ക OTP",
      'verify': "സ്ഥിരീകരിക്കുക",
      'chooseNewPassword': "പുതിയ പാസ്‌വേഡ് തിരഞ്ഞെടുക്കുക",
      'newPasswordAtLeast8': "പുതിയ പാസ്‌വേഡ് (കുറഞ്ഞത് 8 അക്ഷരങ്ങൾ)",
      'updatePassword': "പാസ്‌വേഡ് പുതുക്കുക",
      'passwordUpdatedLogin':
          "പാസ്‌വേഡ് പുതുക്കി. പുതിയ പാസ്‌വേഡ് ഉപയോഗിച്ച് ലോഗിൻ ചെയ്യുക.",
      'registrationSuccessLogin':
          "രജിസ്ട്രേഷൻ വിജയിച്ചു! ദയവായി ലോഗിൻ ചെയ്യുക.",
      'welcomeBackShopper': "വീണ്ടും സ്വാഗതം!",
      'createYourAccount': "നിങ്ങളുടെ അക്കൗണ്ട് സൃഷ്ടിക്കുക",
      'phoneTenDigits': "ഫോൺ (10 അക്കങ്ങൾ)",
      'needAccountRegister': "അക്കൗണ്ട് ഇല്ലേ? രജിസ്റ്റർ ചെയ്യുക",
      'alreadyHaveAccountLogin': "അക്കൗണ്ട് ഉണ്ടോ? ലോഗിൻ ചെയ്യുക",
      'backToHome': "ഹോമിലേക്ക് മടങ്ങുക",
      'unableRequestOtp':
          "ഇപ്പോൾ പാസ്‌വേഡ് പുനഃസജ്ജീകരണം അഭ്യർത്ഥിക്കാൻ കഴിയില്ല.",
      'enterOtpPrompt': "നിങ്ങളുടെ ഇമെയിലിലേക്ക് അയച്ച 6 അക്ക OTP നൽകുക.",
      'invalidExpiredOtp': "OTP അസാധുവാണ് അല്ലെങ്കിൽ കാലഹരണപ്പെട്ടു.",
      'otpUnavailable': "OTP സ്ഥിരീകരിക്കാനായില്ല.",
      'passwordMinLength': "പുതിയ പാസ്‌വേഡിൽ കുറഞ്ഞത് 8 അക്ഷരങ്ങൾ വേണം.",
      'passwordResetFailed':
          "പാസ്‌വേഡ് പുനഃസജ്ജീകരണം പരാജയപ്പെട്ടു. പുതിയ OTP അഭ്യർത്ഥിക്കുക.",
      'customerLoginInvalidSession': "ഉപഭോക്തൃ ലോഗിൻ സെഷൻ അസാധുവാണ്.",
      'authenticationFailed': "ആധികാരികത ഉറപ്പാക്കൽ പരാജയപ്പെട്ടു",
      'paymentStatusLine': "പേയ്മെന്റ്: {method} · {status}",
      'paymentMatchedNotificationHint':
          "കടയിലെ ഉപകരണ അറിയിപ്പുമായി പൊരുത്തപ്പെടുത്തി. ഇത് പേയ്‌മെന്റ് ദാതാവിന്റെ സ്ഥിരീകരണമല്ല; പൊരുത്തപ്പെടുത്തലിനായി UPI റഫറൻസ് സൂക്ഷിക്കുക.",
      'paymentPendingHint':
          "പണമിടപാട് പൊരുത്തപ്പെടുത്തൽ സ്ഥിരീകരണം ഇപ്പോഴും കാത്തിരിപ്പിലാണ്. UPI ആപ്പിൽ നിന്ന് മടങ്ങിയതുകൊണ്ട് മാത്രം ഈ ഓർഡർ പണമടച്ചതായി കണക്കാക്കില്ല.",
      'paymentStatusPaid': "അടച്ചു",
      'paymentStatusPending': "കുടിശ്ശിക",
      'paymentStatusCodDue': "പണമായി നൽകാനുള്ളത്",
      'paymentStatusFailed': "പരാജയപ്പെട്ടു",
      'paymentStatusRefund': "തിരികെ നൽകി",
      'paymentStatusPartial': "ഭാഗികമായി അടച്ചു",
      'appTitle': "റീട്ടെയിൽ മൈൻഡ്",
      'usernameOrEmail': 'ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഇമെയിൽ',
      'easyBilling': 'എളുപ്പത്തിലുള്ള ബില്ലിംഗ്',
      'betterProfits': 'കൂടുതൽ ലാഭം',
      'signInGuidance': 'സൈൻ-ഇൻ നിർദ്ദേശങ്ങൾ കേൾക്കുക',
      'voiceInstructionsLanguage': 'നിങ്ങളുടെ ഭാഷയിൽ ശബ്ദ നിർദ്ദേശങ്ങൾ നേടുക',
      'playVoiceGuidance': 'നിർദ്ദേശങ്ങൾ കേൾക്കുക',
      'stopVoiceGuidance': 'സംസാരിക്കുന്നത് നിർത്തുക',
      'continueWithGoogle': 'Google ഉപയോഗിച്ച് തുടരുക',
      'noAccount': 'അക്കൗണ്ട് ഇല്ലേ?',
      'listenRegisterGuidance': 'രജിസ്ട്രേഷൻ നിർദ്ദേശങ്ങൾ കേൾക്കുക',
      'dataProtected': 'നിങ്ങളുടെ ഡാറ്റ സുരക്ഷിതമാണ്',
      'secureAndSafe': 'സുരക്ഷിതവും ഭദ്രവും',
      'growBusinessInLanguage': 'നിങ്ങളുടെ ഭാഷയിൽ\nനിങ്ങളുടെ ബിസിനസ് വളർത്തുക',
      'or': 'അല്ലെങ്കിൽ',
      'signingIn': 'സൈൻ ഇൻ ചെയ്യുന്നു',
      'verifyingAccount': 'നിങ്ങളുടെ അക്കൗണ്ട് പരിശോധിക്കുന്നു...',
      'creatingAccount': 'നിങ്ങളുടെ അക്കൗണ്ട് സൃഷ്ടിക്കുന്നു',
      'registeringShopSync':
          'നിങ്ങളുടെ കട സുരക്ഷിതമായി രജിസ്റ്റർ ചെയ്ത് ബാക്കെൻഡുമായി സമന്വയിപ്പിക്കുന്നു',
      'tagline': "സ്മാർട്ട് അനലിറ്റിക്സും ബില്ലിംഗ് പ്ലാറ്റ്‌ഫോമും",
      'email': "ഇമെയിൽ",
      'password': "പാസ്‌വേഡ്",
      'login': "ലോഗിൻ",
      'register': "രജിസ്റ്റർ",
      'signIn': "സൈൻ ഇൻ",
      'createAccount': "പുതിയ അക്കൗണ്ട് സൃഷ്ടിക്കുക",
      'signUp': "സൈൻ അപ്പ്",
      'enterEmail': "നിങ്ങളുടെ ഇമെയിൽ നൽകുക",
      'enterPassword': "നിങ്ങളുടെ പാസ്‌വേഡ് നൽകുക",
      'confirmPassword': "പാസ്‌വേഡ് സ്ഥിരീകരിക്കുക",
      'userName': "ഉപയോക്തൃനാമം",
      'shopName': "കടയുടെ പേര്",
      'invalidCredentials': "അസാധുവായ വിവരങ്ങൾ",
      'connectionError': "കണക്ഷൻ പിശക്",
      'welcome': "വീണ്ടും സ്വാഗതം",
      'enterCredentials': "തുടരാൻ നിങ്ങളുടെ വിവരങ്ങൾ നൽകുക",
      'dashboard': "ഡാഷ്ബോർഡ്",
      'sales': "വിൽപ്പന",
      'bills': "ബില്ലുകൾ",
      'settings': "ക്രമീകരണങ്ങൾ",
      'logout': "ലോഗ് ഔട്ട്",
      'language': "ഭാഷ",
      'selectLanguage': "ഭാഷ തിരഞ്ഞെടുക്കുക",
      'forgotPassword': "പാസ്‌വേഡ് മറന്നോ?",
      'welcomeBack': "വീണ്ടും സ്വാഗതം",
      'phone': "ഫോൺ",
      'owner': "ഉടമ",
      'profile': "പ്രൊഫൈൽ",
      'fullName': "പൂർണ്ണനാമം",
      'emailAddress': "ഇമെയിൽ വിലാസം",
      'phoneNumber': "ഫോൺ നമ്പർ",
      'alreadyHaveAccount': "ഇതിനകം അക്കൗണ്ട് ഉണ്ടോ?",
      'inventory': "ഇൻവെന്ററി",
      'reports': "റിപ്പോർട്ടുകൾ",
      'customers': "ഉപഭോക്താക്കൾ",
      'invoices': "ഇൻവോയ്സുകൾ",
      'total': "ആകെ",
      'refresh': "പുതുക്കുക",
      'today': "ഇന്ന്",
      'salesByMonth': "മാസത്തിലെ വിൽപ്പന",
      'salesByWeek': "ആഴ്ചയിലെ വിൽപ്പന",
      'salesByYear': "വർഷത്തിലെ വിൽപ്പന",
      'searchQuery': "തിരയൽ ചോദ്യം",
      'dataUpload': "ഡാറ്റ അപ്‌ലോഡ്",
      'addSale': "വിൽപ്പന ചേർക്കുക",
      'totalAmount': "ആകെ തുക",
      'recordedSuccess': "വിജയകരമായി രേഖപ്പെടുത്തി!",
      'recordedLocally': "പ്രാദേശികമായി സംരക്ഷിച്ചു!",
      'askMeAnything': "എന്തും ചോദിക്കൂ...",
      'aiAssistant': "AI സഹായി",
      'performanceOverview': "പ്രകടന അവലോകനം",
      'transactions': "ഇടപാടുകൾ",
      'avgOrder': "ശരാശരി ഓർഡർ",
      'products': "ഉൽപ്പന്നങ്ങൾ",
      'quickActions': "ദ്രുത പ്രവർത്തനങ്ങൾ",
      'getInsights': "അവലോകനങ്ങൾ നേടുക",
      'week': "ആഴ്ച",
      'month': "മാസം",
      'year': "വർഷം",
      'showing': "കാണിക്കുന്നു",
      'website': "വെബ്‌സൈറ്റ്",
      'shopkeeper': "കടയുടമ",
      'shareCard': "കാർഡ് പങ്കിടുക",
      'viewBack': "പിന്നിൽ കാണുക",
      'viewFront': "മുൻവശം കാണുക",
      'goToDashboard': "ഡാഷ്ബോർഡിലേക്ക് പോകുക",
      'scanToConnect': "ബന്ധിപ്പിക്കാൻ സ്കാൻ ചെയ്യുക",
      'personalInfo': "വ്യക്തിഗത വിവരം",
      'shopDetails': "കടയുടെ വിവരങ്ങൾ",
      'security': "സുരക്ഷ",
      'shopType': "കടയുടെ തരം",
      'taglineOptional': "ടാഗ്‌ലൈൻ (ഐച്ഛികം)",
      'websiteOptional': "വെബ്‌സൈറ്റ് (ഐച്ഛികം)",
      'analytics': "വിശകലനം",
      'last7Days': "കഴിഞ്ഞ 7 ദിവസം",
      'last30Days': "കഴിഞ്ഞ 30 ദിവസം",
      'thisYear': "ഈ വർഷം",
      'noInsights': "അവലോകനങ്ങളൊന്നുമില്ല",
      'goodMorning': "സുപ്രഭാതം!",
      'synced': "സമന്വയിപ്പിച്ചു",
      'performanceMessage': "ഇന്ന് നിങ്ങളുടെ കടയുടെ പ്രകടനം",
      'salesTrend': "വിൽപ്പന പ്രവണത",
      'revenueDistribution': "വരുമാന വിതരണം",
      'quantityDistribution': "അളവ് വിതരണം",
      'revenueLeaders': "കൂടുതൽ വരുമാനമുള്ള ഉൽപ്പന്നങ്ങൾ",
      'whatChartShows': "ഈ ചാർട്ട് എന്താണ് കാണിക്കുന്നത്?",
      'askSimpleLanguage': "ലളിതമായ ഭാഷയിൽ ചോദിക്കുക",
      'askButton': "ചോദിക്കുക",
      'enterProductDetails': "ഉൽപ്പന്ന വിവരങ്ങൾ താഴെ നൽകുക",
      'addProduct': "ഉൽപ്പന്നം ചേർക്കുക",
      'generateBill': "ബിൽ സൃഷ്ടിക്കുക",
      'saveSales': "വിൽപ്പന സംരക്ഷിക്കുക",
      'paymentMethod': "പണമടയ്ക്കൽ രീതി",
      'cashOffline': "പണം / ഓഫ്‌ലൈൻ",
      'onlineUPI': "ഓൺലൈൻ / UPI",
      'confirmPayment': "പണം ലഭിച്ചതായി സ്ഥിരീകരിക്കുക",
      'paymentConfirmed': "പേയ്മെന്റ് സ്ഥിരീകരിച്ചു",
      'noSalesData': "വിൽപ്പന വിവരങ്ങളൊന്നുമില്ല",
      'uploadInventory': "സ്റ്റോക്ക് അപ്‌ലോഡ്",
      'selectFile': "ഫയൽ തിരഞ്ഞെടുക്കുക",
      'upload': "അപ്‌ലോഡ്",
      'analyticsOverview': "വിശകലന അവലോകനം",
      'askToScan': "സ്കാൻ ചെയ്ത് പണമടയ്ക്കാൻ ഉപഭോക്താവിനോട് പറയുക",
      'scannedBillTitle': "സ്കാൻ ചെയ്ത ബിൽ",
      'askYourQuestion': "നിങ്ങളുടെ ചോദ്യം ചോദിക്കുക",
      'analysisResults': "വിശകലന ഫലങ്ങൾ",
      'analysisSummary': "വിശകലന സംഗ്രഹം",
      'detailedData': "വിശദമായ ഡാറ്റ",
      'revenueShare': "വരുമാന വിഹിതം",
      'topProductsByRevenue': "വരുമാനത്തിൽ മുന്നിലുള്ള ഉൽപ്പന്നങ്ങൾ",
      'volumeAnalysis': "അളവ് വിശകലനം",
      'unitMovementRadar': "യൂണിറ്റ് ചലന റഡാർ",
      'upwardTrend': "ഉയരുന്ന പ്രവണത",
      'downwardTrend': "താഴുന്ന പ്രവണത",
      'noProductData': "ഉൽപ്പന്ന ഡാറ്റയില്ല",
      'volumeByProduct': "ഉൽപ്പന്നം അനുസരിച്ചുള്ള അളവ്",
      'selectDueDate': "അവസാന തീയതി തിരഞ്ഞെടുക്കുക",
      'deadline': "അവസാന തീയതി",
      'overdue': "കാലാവധി കഴിഞ്ഞു",
      'pendingPayment': "കുടിശ്ശിക പേയ്മെന്റ്",
      'setDeadline': "അവസാന തീയതി സജ്ജമാക്കുക",
      'attendance': "ഹാജർ",
      'addCustomer': "ഉപഭോക്താവിനെ ചേർക്കുക",
      'customerName': "ഉപഭോക്താവിന്റെ പേര്",
      'newInvoice': "പുതിയ ഇൻവോയ്സ്",
      'noInvoicesFound': "ഇൻവോയ്സുകൾ കണ്ടെത്തിയില്ല",
      'noCustomersYet': "ഇതുവരെ ഉപഭോക്താക്കളില്ല",
      'noProductsYet': "ഇതുവരെ ഉൽപ്പന്നങ്ങളില്ല",
      'checkIn': "ചെക്ക് ഇൻ",
      'checkOut': "ചെക്ക് ഔട്ട്",
      'todayStatus': "ഇന്നത്തെ നില",
      'history': "ചരിത്രം",
      'viewAll': "എല്ലാം കാണുക",
      'mrp': "പരമാവധി ചില്ലറ വില",
      'rate': "നിരക്ക്",
      'qty': "അളവ്",
      'amt': "തുക",
      'description': "വിവരണം",
      'billNo': "ബിൽ നമ്പർ",
      'date': "തീയതി",
      'time': "സമയം",
      'cashier': "കാഷ്യർ",
      'counter': "കൗണ്ടർ",
      'cashBill': "കാഷ് ബിൽ",
      'youHaveSaved': "നിങ്ങൾ സംരക്ഷിച്ചത്",
      'thankYouVisitAgain': "നന്ദി - വീണ്ടും വരിക",
      'items': "ഇനങ്ങൾ",
      'cash': "പണം",
      'serve': "സേവനം",
      'discount': "ഡിസ്‌കൗണ്ട്",
      'expenses': "ചെലവുകൾ",
      'workers': "തൊഴിലാളികൾ",
      'backup': "ബാക്കപ്പ് & പുനഃസ്ഥാപിക്കുക",
      'location': "സ്ഥലം",
      'query': "ചോദ്യം",
      'giftCard': "ഗിഫ്റ്റ് കാർഡ്",
      'insights': "അവലോകനങ്ങൾ",
      'darkMode': "ഡാർക്ക് മോഡ്",
      'notification': "അറിയിപ്പുകൾ",
      'about': "വിവരം",
      'share': "പങ്കിടുക",
      'help': "സഹായം",
      'alwaysHere': "സഹായിക്കാൻ എപ്പോഴും തയ്യാറാണ്",
      'tapToFlip': "QR കോഡിനായി തിരിക്കാൻ ടാപ്പ് ചെയ്യുക",
      'tapToSeeFront': "മുൻഭാഗം കാണാൻ ടാപ്പ് ചെയ്യുക",
      'orScan': "അല്ലെങ്കിൽ സ്കാൻ ചെയ്യുക",
      'allContactIncluded':
          "എല്ലാ ബന്ധപ്പെടാനുള്ള വിവരങ്ങളും ഉൾപ്പെടുത്തിയിട്ടുണ്ട്",
      'joinCommunity': "ഞങ്ങളുടെ കൂട്ടായ്മയിൽ ചേരുക",
      'uploadData': "ഡാറ്റ അപ്‌ലോഡ് ചെയ്യുക",
      'askQuestionHint':
          "ചോദ്യം ചോദിക്കുക (ഉദാ: കഴിഞ്ഞ ആഴ്ചയിലെ വിൽപ്പന കാണിക്കുക)",
      'queryTip': "സൂചന: ഡാറ്റാബേസിൽ ചോദ്യം ചെയ്യാൻ ഫയൽ ശൂന്യമായി വിടുക",
      'responseHint': "മറുപടി ഇവിടെ കാണിക്കും",
      'avgChange': "ശരാശരി മാറ്റം",
      'revenueLeadersDesc':
          "തിരഞ്ഞെടുത്ത കാലയളവിലെ വരുമാനമനുസരിച്ചുള്ള മികച്ച ഉൽപ്പന്നങ്ങൾ ഈ ബാർ ചാർട്ട് കാണിക്കുന്നു.",
      'salesTrendDesc':
          "സമീപകാല ദിവസങ്ങളിലെ മൊത്തം വിൽപ്പനയും കടയുടെ പുരോഗതിയും ഈ ലൈൻ ചാർട്ട് കാണിക്കുന്നു.",
      'revenueDistributionDesc':
          "മൊത്തം വരുമാനത്തിൽ ഓരോ ഉൽപ്പന്നത്തിന്റെയും പങ്ക് ഈ പൈ ചാർട്ട് കാണിക്കുന്നു.",
      'quantityDistributionDesc':
          "ഓരോ ഉൽപ്പന്നത്തിന്റെയും വിറ്റ യൂണിറ്റുകൾ ഈ റഡാർ ചാർട്ട് താരതമ്യം ചെയ്യുന്നു.",
      'monthlySalesDesc':
          "ഓരോ മാസത്തെയും മൊത്തം വിൽപ്പന നിരീക്ഷിക്കുക. വർഷത്തിലെ പ്രവണതകളും ഏറ്റവും കൂടുതൽ വിൽപ്പനയുള്ള സമയവും കണ്ടെത്തുക.",
      'weeklySalesDesc':
          "കഴിഞ്ഞ 12 ആഴ്ചകളിലെ വിൽപ്പന കാണുക. ആഴ്ചയിലെ രീതികളും വളർച്ചയും തിരിച്ചറിയുക.",
      'yearlySalesDesc':
          "വ്യത്യസ്ത വർഷങ്ങളിലെ മൊത്തം വിൽപ്പന താരതമ്യം ചെയ്ത് ദീർഘകാല വളർച്ച നിരീക്ഷിക്കുക.",
      'howToUseTitle': "Retail Mind എങ്ങനെ ഉപയോഗിക്കാം",
      'step1Title': "1. വിൽപ്പന ചേർക്കുക",
      'step1Desc':
          "വിൽപ്പന ചേർക്കുക ഐക്കൺ ഉപയോഗിച്ച് ഓരോ വിൽപ്പനയും രേഖപ്പെടുത്തുക.",
      'step2Title': "2. സ്റ്റോക്ക് നിയന്ത്രിക്കുക",
      'step2Desc': "ഇൻവെന്ററി സ്ക്രീനിൽ ഉൽപ്പന്നങ്ങളുടെ സ്റ്റോക്ക് പിന്തുടരുക.",
      'step3Title': "3. റിപ്പോർട്ടുകൾ കാണുക",
      'step3Desc': "വിശദമായ വിശകലനത്തിന് റിപ്പോർട്ടുകൾ വിഭാഗം തുറക്കുക.",
      'step4Title': "4. ഗിഫ്റ്റ് കാർഡ് പങ്കിടുക",
      'step4Desc': "ഡിജിറ്റൽ ഗിഫ്റ്റ് കാർഡ് ഉപഭോക്താക്കൾക്ക് അയയ്ക്കുക.",
      'step5Title': "5. പേയ്‌മെന്റുകൾ സ്വീകരിക്കുക",
      'step5Desc': "പണം സ്വീകരിക്കാൻ നിങ്ങളുടെ QR കോഡ് കാണിക്കുക.",
      'gotIt': "മനസ്സിലായി!",
      'dailyPerformanceRating': "ദൈനംദിന പ്രകടന വിലയിരുത്തൽ",
      'salesIncreasedBy': "ഇന്നത്തെ വിൽപ്പന വർധിച്ചത്",
      'salesDecreasedBy': "ഇന്നത്തെ വിൽപ്പന കുറഞ്ഞത്",
      'bestHour': "മികച്ച മണിക്കൂർ",
      'yesterdayBestProduct': "ഇന്നലത്തെ മികച്ച ഉൽപ്പന്നം:",
      'noSales': "വിൽപ്പനയില്ല",
      'notAvailable': "ലഭ്യമല്ല",
      'todaySales': "ഇന്നത്തെ വിൽപ്പന",
      'yesterdaySales': "ഇന്നലത്തെ വിൽപ്പന",
      'analysisAmazing':
          "അദ്ഭുതം! ഇന്ന് നിങ്ങൾ ₹{0} നേടി; ഇത് ഇന്നലത്തേതിനേക്കാൾ ₹{1} കൂടുതലാണ്!",
      'analysisProgressing':
          "വിൽപ്പന മെച്ചപ്പെടുന്നു! ഇന്ന് ₹{0} വിൽപ്പനയായി. ഇന്നലത്തെക്കാൾ മുന്നിലെത്താൻ ₹{1} കൂടി വേണം.",
      'analysisWaiting':
          "ഇന്നത്തെ ആദ്യ വിൽപ്പനയ്ക്കായി കാത്തിരിക്കുന്നു. ഇന്നത്തെ ദിവസം മികച്ചതാക്കാം!",
      'analysisMatch':
          "ഇന്നത്തെ വിൽപ്പനയും ഇന്നലത്തേതുപോലെ ₹{0}! സ്ഥിരതയുള്ള പ്രകടനം.",
      'goodMorningName': "സുപ്രഭാതം, {0}! ☀️",
      'goodAfternoonName': "ശുഭ ഉച്ചയ്ക്ക്, {0}! 🌤️",
      'goodEveningName': "ശുഭ സായാഹ്നം, {0}! 🌙",
      'tapToUploadQr': "QR അപ്‌ലോഡ് ചെയ്യാൻ ടാപ്പ് ചെയ്യുക",
      'qrUploadFormat': "ഗാലറിയിൽ നിന്ന് PNG / JPG",
      'tripleChannelActive': "മൂന്ന് ചാനൽ കണ്ടെത്തൽ സജീവമാണ്",
      'listeningForPayments': "UPI, SMS, സ്ക്രീൻ എന്നിവ ശ്രദ്ധിക്കുന്നു...",
    },
    'mr': {
      'username': "वापरकर्तानाव",
      'chooseUsername': "वापरकर्तानाव निवडा",
      'shopDisplayName': "तुमच्या दुकानाचे प्रदर्शित नाव",
      'optional': "पर्यायी",
      'secure': "सुरक्षित",
      'resetCustomerPassword': "ग्राहकाचा पासवर्ड रीसेट करा",
      'accountEmail': "खात्याचा ईमेल",
      'sendOtp': "OTP पाठवा",
      'cancel': "रद्द करा",
      'enterVerificationCode': "पडताळणी कोड प्रविष्ट करा",
      'otpSixDigits': "6 अंकी OTP",
      'verify': "पडताळा",
      'chooseNewPassword': "नवीन पासवर्ड निवडा",
      'newPasswordAtLeast8': "नवीन पासवर्ड (किमान 8 अक्षरे)",
      'updatePassword': "पासवर्ड अपडेट करा",
      'passwordUpdatedLogin':
          "पासवर्ड अपडेट केला आहे. कृपया नवीन पासवर्डने लॉगिन करा.",
      'registrationSuccessLogin': "नोंदणी यशस्वी! कृपया लॉगिन करा.",
      'welcomeBackShopper': "पुन्हा स्वागत आहे!",
      'createYourAccount': "तुमचे खाते तयार करा",
      'phoneTenDigits': "फोन (10 अंक)",
      'needAccountRegister': "खाते नाही? नोंदणी करा",
      'alreadyHaveAccountLogin': "आधीच खाते आहे? लॉगिन करा",
      'backToHome': "मुख्यपृष्ठावर परत जा",
      'unableRequestOtp': "सध्या पासवर्ड रीसेटची विनंती करता येत नाही.",
      'enterOtpPrompt': "तुमच्या ईमेलवर पाठवलेला 6 अंकी OTP प्रविष्ट करा.",
      'invalidExpiredOtp': "OTP अवैध आहे किंवा कालबाह्य झाला आहे.",
      'otpUnavailable': "OTP पडताळता आला नाही.",
      'passwordMinLength': "नवीन पासवर्डमध्ये किमान 8 अक्षरे असावीत.",
      'passwordResetFailed': "पासवर्ड रीसेट अयशस्वी. नवीन OTP मागवा.",
      'customerLoginInvalidSession': "ग्राहक लॉगिन सत्र अवैध आहे.",
      'authenticationFailed': "प्रमाणीकरण अयशस्वी",
      'paymentStatusLine': "पेमेंट: {method} · {status}",
      'paymentMatchedNotificationHint':
          "दुकानातील डिव्हाइस सूचनेशी जुळवले. ही पेमेंट प्रदात्याची पुष्टी नाही; पडताळणीसाठी UPI संदर्भ जतन करा.",
      'paymentPendingHint':
          "पेमेंट जुळवणीची पुष्टी अजून प्रलंबित आहे. UPI अॅपमधून परत आल्यानेच ही ऑर्डर भरलेली मानली जात नाही.",
      'paymentStatusPaid': "भरले",
      'paymentStatusPending': "प्रलंबित",
      'paymentStatusCodDue': "रोख बाकी",
      'paymentStatusFailed': "अयशस्वी",
      'paymentStatusRefund': "परत केले",
      'paymentStatusPartial': "अंशतः भरले",
      'appTitle': "रिटेल माइंड",
      'usernameOrEmail': 'वापरकर्तानाव किंवा ईमेल',
      'easyBilling': 'सोपे बिलिंग',
      'betterProfits': 'अधिक नफा',
      'signInGuidance': 'साइन-इन मार्गदर्शन ऐका',
      'voiceInstructionsLanguage': 'तुमच्या भाषेत आवाजातील सूचना मिळवा',
      'playVoiceGuidance': 'मार्गदर्शन ऐका',
      'stopVoiceGuidance': 'बोलणे थांबवा',
      'continueWithGoogle': 'Google सह पुढे जा',
      'noAccount': 'खाते नाही?',
      'listenRegisterGuidance': 'नोंदणीचे मार्गदर्शन ऐका',
      'dataProtected': 'तुमचा डेटा सुरक्षित आहे',
      'secureAndSafe': 'सुरक्षित आणि संरक्षित',
      'growBusinessInLanguage': 'तुमच्या भाषेत\nतुमचा व्यवसाय वाढवा',
      'or': 'किंवा',
      'signingIn': 'साइन इन करत आहे',
      'verifyingAccount': 'तुमचे खाते तपासत आहे...',
      'creatingAccount': 'तुमचे खाते तयार करत आहे',
      'registeringShopSync':
          'तुमचे दुकान सुरक्षितपणे नोंदवून बॅकएंडशी सिंक करत आहे',
      'tagline': "स्मार्ट विश्लेषण आणि बिलिंग प्लॅटफॉर्म",
      'email': "ईमेल",
      'password': "पासवर्ड",
      'login': "लॉगिन",
      'register': "नोंदणी",
      'signIn': "साइन इन",
      'createAccount': "नवीन खाते तयार करा",
      'signUp': "साइन अप",
      'enterEmail': "तुमचा ईमेल प्रविष्ट करा",
      'enterPassword': "तुमचा पासवर्ड प्रविष्ट करा",
      'confirmPassword': "पासवर्डची पुष्टी करा",
      'userName': "वापरकर्तानाव",
      'shopName': "दुकानाचे नाव",
      'invalidCredentials': "अवैध माहिती",
      'connectionError': "कनेक्शन त्रुटी",
      'welcome': "पुन्हा स्वागत",
      'enterCredentials': "पुढे जाण्यासाठी तुमची माहिती प्रविष्ट करा",
      'dashboard': "डॅशबोर्ड",
      'sales': "विक्री",
      'bills': "बिले",
      'settings': "सेटिंग्ज",
      'logout': "लॉग आउट",
      'language': "भाषा",
      'selectLanguage': "भाषा निवडा",
      'forgotPassword': "पासवर्ड विसरलात?",
      'welcomeBack': "पुन्हा स्वागत",
      'phone': "फोन",
      'owner': "मालक",
      'profile': "प्रोफाइल",
      'fullName': "पूर्ण नाव",
      'emailAddress': "ईमेल पत्ता",
      'phoneNumber': "फोन नंबर",
      'alreadyHaveAccount': "आधीच खाते आहे?",
      'inventory': "साठा",
      'reports': "अहवाल",
      'customers': "ग्राहक",
      'invoices': "चलने",
      'total': "एकूण",
      'refresh': "रीफ्रेश",
      'today': "आज",
      'salesByMonth': "महिन्यानुसार विक्री",
      'salesByWeek': "आठवड्यानुसार विक्री",
      'salesByYear': "वर्षानुसार विक्री",
      'searchQuery': "शोध प्रश्न",
      'dataUpload': "डेटा अपलोड",
      'addSale': "विक्री जोडा",
      'totalAmount': "एकूण रक्कम",
      'recordedSuccess': "यशस्वीरित्या नोंदवले!",
      'recordedLocally': "स्थानिकरीत्या जतन केले!",
      'askMeAnything': "काहीही विचारा...",
      'aiAssistant': "AI सहाय्यक",
      'performanceOverview': "कामगिरीचा आढावा",
      'transactions': "व्यवहार",
      'avgOrder': "सरासरी ऑर्डर",
      'products': "उत्पादने",
      'quickActions': "जलद कृती",
      'getInsights': "अंतर्दृष्टी मिळवा",
      'week': "आठवडा",
      'month': "महिना",
      'year': "वर्ष",
      'showing': "दाखवत आहे",
      'website': "वेबसाइट",
      'shopkeeper': "दुकानदार",
      'shareCard': "कार्ड शेअर करा",
      'viewBack': "मागील बाजू पहा",
      'viewFront': "समोरील बाजू पहा",
      'goToDashboard': "डॅशबोर्डवर जा",
      'scanToConnect': "जोडण्यासाठी स्कॅन करा",
      'personalInfo': "वैयक्तिक माहिती",
      'shopDetails': "दुकानाचे तपशील",
      'security': "सुरक्षा",
      'shopType': "दुकानाचा प्रकार",
      'taglineOptional': "टॅगलाइन (पर्यायी)",
      'websiteOptional': "वेबसाइट (पर्यायी)",
      'analytics': "विश्लेषण",
      'last7Days': "मागील 7 दिवस",
      'last30Days': "मागील 30 दिवस",
      'thisYear': "हे वर्ष",
      'noInsights': "अंतर्दृष्टी उपलब्ध नाही",
      'goodMorning': "शुभ सकाळ!",
      'synced': "समक्रमित",
      'performanceMessage': "आज तुमच्या दुकानाची कामगिरी",
      'salesTrend': "विक्रीचा कल",
      'revenueDistribution': "महसुलाचे वितरण",
      'quantityDistribution': "प्रमाणाचे वितरण",
      'revenueLeaders': "सर्वाधिक महसूल देणारी उत्पादने",
      'whatChartShows': "हा चार्ट काय दाखवतो?",
      'askSimpleLanguage': "सोप्या भाषेत विचारा",
      'askButton': "विचारा",
      'enterProductDetails': "खाली उत्पादनांचे तपशील भरा",
      'addProduct': "उत्पादन जोडा",
      'generateBill': "बिल तयार करा",
      'saveSales': "विक्री जतन करा",
      'paymentMethod': "पेमेंट पद्धत",
      'cashOffline': "रोख / ऑफलाइन",
      'onlineUPI': "ऑनलाइन / UPI",
      'confirmPayment': "पेमेंट मिळाल्याची पुष्टी करा",
      'paymentConfirmed': "पेमेंट निश्चित",
      'noSalesData': "विक्रीची माहिती उपलब्ध नाही",
      'uploadInventory': "साठा अपलोड करा",
      'selectFile': "फाइल निवडा",
      'upload': "अपलोड",
      'analyticsOverview': "विश्लेषणाचा आढावा",
      'askToScan': "स्कॅन करून पेमेंट करण्यास ग्राहकाला सांगा",
      'scannedBillTitle': "स्कॅन केलेले बिल",
      'askYourQuestion': "तुमचा प्रश्न विचारा",
      'analysisResults': "विश्लेषणाचे परिणाम",
      'analysisSummary': "विश्लेषणाचा सारांश",
      'detailedData': "तपशीलवार डेटा",
      'revenueShare': "महसुलातील वाटा",
      'topProductsByRevenue': "महसुलानुसार प्रमुख उत्पादने",
      'volumeAnalysis': "प्रमाण विश्लेषण",
      'unitMovementRadar': "युनिट हालचाली रडार",
      'upwardTrend': "वाढता कल",
      'downwardTrend': "घटता कल",
      'noProductData': "उत्पादन डेटा नाही",
      'volumeByProduct': "उत्पादनानुसार प्रमाण",
      'selectDueDate': "देय तारीख निवडा",
      'deadline': "अंतिम तारीख",
      'overdue': "मुदत संपली",
      'pendingPayment': "प्रलंबित पेमेंट",
      'setDeadline': "अंतिम तारीख सेट करा",
      'attendance': "उपस्थिती",
      'addCustomer': "ग्राहक जोडा",
      'customerName': "ग्राहकाचे नाव",
      'newInvoice': "नवीन चलन",
      'noInvoicesFound': "चलने आढळली नाहीत",
      'noCustomersYet': "अजून ग्राहक नाहीत",
      'noProductsYet': "अजून उत्पादने नाहीत",
      'checkIn': "चेक इन",
      'checkOut': "चेक आउट",
      'todayStatus': "आजची स्थिती",
      'history': "इतिहास",
      'viewAll': "सर्व पहा",
      'mrp': "कमाल किरकोळ किंमत",
      'rate': "दर",
      'qty': "प्रमाण",
      'amt': "रक्कम",
      'description': "वर्णन",
      'billNo': "बिल क्रमांक",
      'date': "तारीख",
      'time': "वेळ",
      'cashier': "कॅशियर",
      'counter': "काउंटर",
      'cashBill': "रोख बिल",
      'youHaveSaved': "तुम्ही वाचवले",
      'thankYouVisitAgain': "धन्यवाद - पुन्हा भेट द्या",
      'items': "वस्तू",
      'cash': "रोख",
      'serve': "सेवा",
      'discount': "सवलत",
      'expenses': "खर्च",
      'workers': "कामगार",
      'backup': "बॅकअप आणि पुनर्संचयित करा",
      'location': "स्थान",
      'query': "प्रश्न",
      'giftCard': "भेट कार्ड",
      'insights': "महत्त्वाची माहिती",
      'darkMode': "डार्क मोड",
      'notification': "सूचना",
      'about': "माहिती",
      'share': "शेअर करा",
      'help': "मदत",
      'alwaysHere': "मदतीसाठी नेहमी उपलब्ध",
      'tapToFlip': "QR कोडसाठी उलटवण्यासाठी टॅप करा",
      'tapToSeeFront': "पुढील बाजू पाहण्यासाठी टॅप करा",
      'orScan': "किंवा स्कॅन करा",
      'allContactIncluded': "सर्व संपर्क माहिती समाविष्ट आहे",
      'joinCommunity': "आमच्या समुदायात सामील व्हा",
      'uploadData': "डेटा अपलोड करा",
      'askQuestionHint': "प्रश्न विचारा (उदा. मागील आठवड्याची विक्री दाखवा)",
      'queryTip': "सूचना: डेटाबेसला प्रश्न विचारण्यासाठी फाइल रिकामी ठेवा",
      'responseHint': "उत्तर येथे दिसेल",
      'avgChange': "सरासरी बदल",
      'revenueLeadersDesc':
          "हा बार चार्ट निवडलेल्या कालावधीत महसुलानुसार अव्वल उत्पादने दाखवतो.",
      'salesTrendDesc':
          "हा रेषा आलेख अलीकडील दिवसांची एकूण विक्री दाखवून दुकानाची प्रगती समजण्यास मदत करतो.",
      'revenueDistributionDesc':
          "हा पाय चार्ट एकूण महसुलातील प्रत्येक उत्पादनाचा वाटा दाखवतो.",
      'quantityDistributionDesc':
          "हा रडार चार्ट प्रत्येक उत्पादनाच्या विकलेल्या युनिट्सची तुलना करतो.",
      'monthlySalesDesc':
          "प्रत्येक महिन्याची एकूण विक्री नोंदवा. वर्षातील कल आणि सर्वाधिक विक्रीचे कालावधी ओळखा.",
      'weeklySalesDesc':
          "मागील 12 आठवड्यांची विक्री पाहा. साप्ताहिक नमुने आणि वाढ ओळखा.",
      'yearlySalesDesc':
          "वेगवेगळ्या वर्षांतील एकूण विक्रीची तुलना करून दीर्घकालीन वाढ पाहा.",
      'howToUseTitle': "Retail Mind कसे वापरावे",
      'step1Title': "1. विक्री जोडा",
      'step1Desc': "विक्री जोडा चिन्ह वापरून प्रत्येक विक्री नोंदवा.",
      'step2Title': "2. साठा व्यवस्थापित करा",
      'step2Desc': "इन्व्हेंटरी स्क्रीनमधून उत्पादनांचा साठा पाहा.",
      'step3Title': "3. अहवाल पाहा",
      'step3Desc': "सखोल विश्लेषणासाठी अहवाल विभाग उघडा.",
      'step4Title': "4. भेट कार्ड शेअर करा",
      'step4Desc': "डिजिटल भेट कार्ड ग्राहकांना पाठवा.",
      'step5Title': "5. पैसे स्वीकारा",
      'step5Desc': "पेमेंट सहज मिळवण्यासाठी तुमचा QR कोड दाखवा.",
      'gotIt': "समजले!",
      'dailyPerformanceRating': "दैनंदिन कामगिरीचे मूल्यांकन",
      'salesIncreasedBy': "आजची विक्री इतकी वाढली",
      'salesDecreasedBy': "आजची विक्री इतकी कमी झाली",
      'bestHour': "सर्वोत्तम तास",
      'yesterdayBestProduct': "कालचे सर्वोत्तम उत्पादन:",
      'noSales': "विक्री नाही",
      'notAvailable': "उपलब्ध नाही",
      'todaySales': "आजची विक्री",
      'yesterdaySales': "कालची विक्री",
      'analysisAmazing': "छान! आज तुम्ही ₹{0} कमावले, कालपेक्षा ₹{1} जास्त!",
      'analysisProgressing':
          "विक्रीत सुधारणा होत आहे! आज ₹{0} ची विक्री झाली. कालपेक्षा पुढे जाण्यासाठी ₹{1} बाकी आहेत.",
      'analysisWaiting':
          "आजच्या पहिल्या विक्रीची वाट पाहत आहोत. आजचा दिवस उत्तम बनवूया!",
      'analysisMatch': "आजची विक्री कालइतकीच ₹{0}! सातत्यपूर्ण कामगिरी.",
      'goodMorningName': "शुभ प्रभात, {0}! ☀️",
      'goodAfternoonName': "शुभ दुपार, {0}! 🌤️",
      'goodEveningName': "शुभ संध्याकाळ, {0}! 🌙",
      'tapToUploadQr': "QR अपलोड करण्यासाठी टॅप करा",
      'qrUploadFormat': "गॅलरीमधून PNG / JPG",
      'tripleChannelActive': "तीन-चॅनेल ओळख सुरू आहे",
      'listeningForPayments': "UPI, SMS आणि स्क्रीनवरील सूचनांकडे लक्ष आहे...",
    },
    'gu': {
      'username': "વપરાશકર્તા નામ",
      'chooseUsername': "વપરાશકર્તા નામ પસંદ કરો",
      'shopDisplayName': "તમારી દુકાનનું પ્રદર્શિત નામ",
      'optional': "વૈકલ્પિક",
      'secure': "સુરક્ષિત",
      'resetCustomerPassword': "ગ્રાહકનો પાસવર્ડ રીસેટ કરો",
      'accountEmail': "ખાતાનું ઈમેલ",
      'sendOtp': "OTP મોકલો",
      'cancel': "રદ કરો",
      'enterVerificationCode': "ચકાસણી કોડ દાખલ કરો",
      'otpSixDigits': "6 અંકનો OTP",
      'verify': "ચકાસો",
      'chooseNewPassword': "નવો પાસવર્ડ પસંદ કરો",
      'newPasswordAtLeast8': "નવો પાસવર્ડ (ઓછામાં ઓછા 8 અક્ષરો)",
      'updatePassword': "પાસવર્ડ અપડેટ કરો",
      'passwordUpdatedLogin':
          "પાસવર્ડ અપડેટ થયો. કૃપા કરીને નવા પાસવર્ડથી લૉગિન કરો.",
      'registrationSuccessLogin': "નોંધણી સફળ! કૃપા કરીને લૉગિન કરો.",
      'welcomeBackShopper': "ફરી સ્વાગત છે!",
      'createYourAccount': "તમારું ખાતું બનાવો",
      'phoneTenDigits': "ફોન (10 અંક)",
      'needAccountRegister': "ખાતું નથી? નોંધણી કરો",
      'alreadyHaveAccountLogin': "પહેલેથી ખાતું છે? લૉગિન કરો",
      'backToHome': "હોમ પર પાછા જાઓ",
      'unableRequestOtp': "હાલમાં પાસવર્ડ રીસેટની વિનંતી કરી શકાતી નથી.",
      'enterOtpPrompt': "તમારા ઈમેલ પર મોકલેલો 6 અંકનો OTP દાખલ કરો.",
      'invalidExpiredOtp': "OTP અમાન્ય છે અથવા સમય સમાપ્ત થયો છે.",
      'otpUnavailable': "OTP ચકાસી શકાયો નથી.",
      'passwordMinLength': "નવા પાસવર્ડમાં ઓછામાં ઓછા 8 અક્ષરો હોવા જોઈએ.",
      'passwordResetFailed': "પાસવર્ડ રીસેટ નિષ્ફળ. નવો OTP માંગો.",
      'customerLoginInvalidSession': "ગ્રાહક લૉગિન સત્ર અમાન્ય છે.",
      'authenticationFailed': "પ્રમાણીકરણ નિષ્ફળ",
      'paymentStatusLine': "ચુકવણી: {method} · {status}",
      'paymentMatchedNotificationHint':
          "દુકાનના ઉપકરણની સૂચના સાથે મેળ ખાતું થયું. આ ચુકવણી પ્રદાતાની પુષ્ટિ નથી; સમાધાન માટે UPI સંદર્ભ સાચવો.",
      'paymentPendingHint':
          "ચુકવણીના મેળની પુષ્ટિ હજી બાકી છે. UPI એપમાંથી પાછા આવવાથી આ ઓર્ડર ચૂકવાયેલો ગણાતો નથી.",
      'paymentStatusPaid': "ચૂકવેલ",
      'paymentStatusPending': "બાકી",
      'paymentStatusCodDue': "રોકડ બાકી",
      'paymentStatusFailed': "નિષ્ફળ",
      'paymentStatusRefund': "પરત કરેલ",
      'paymentStatusPartial': "આંશિક ચૂકવણી",
      'appTitle': "રિટેલ માઇન્ડ",
      'usernameOrEmail': 'વપરાશકર્તા નામ અથવા ઇમેઇલ',
      'easyBilling': 'સરળ બિલિંગ',
      'betterProfits': 'વધુ નફો',
      'signInGuidance': 'સાઇન-ઇન માર્ગદર્શન સાંભળો',
      'voiceInstructionsLanguage': 'તમારી ભાષામાં અવાજની સૂચનાઓ મેળવો',
      'playVoiceGuidance': 'માર્ગદર્શન સાંભળો',
      'stopVoiceGuidance': 'બોલવાનું બંધ કરો',
      'continueWithGoogle': 'Google સાથે ચાલુ રાખો',
      'noAccount': 'ખાતું નથી?',
      'listenRegisterGuidance': 'નોંધણી માર્ગદર્શન સાંભળો',
      'dataProtected': 'તમારો ડેટા સુરક્ષિત છે',
      'secureAndSafe': 'સુરક્ષિત અને સલામત',
      'growBusinessInLanguage': 'તમારી ભાષામાં\nતમારા વ્યવસાયને વિકસાવો',
      'or': 'અથવા',
      'signingIn': 'સાઇન ઇન થઈ રહ્યું છે',
      'verifyingAccount': 'તમારા ખાતાની ચકાસણી થઈ રહી છે...',
      'creatingAccount': 'તમારું ખાતું બનાવવામાં આવી રહ્યું છે',
      'registeringShopSync':
          'તમારી દુકાન સુરક્ષિત રીતે નોંધાઈ રહી છે અને બેકએન્ડ સાથે સમન્વયિત થઈ રહી છે',
      'tagline': "સ્માર્ટ વિશ્લેષણ અને બિલિંગ પ્લેટફોર્મ",
      'email': "ઈમેલ",
      'password': "પાસવર્ડ",
      'login': "લૉગિન",
      'register': "નોંધણી",
      'signIn': "સાઇન ઇન",
      'createAccount': "નવું ખાતું બનાવો",
      'signUp': "સાઇન અપ",
      'enterEmail': "તમારો ઈમેલ દાખલ કરો",
      'enterPassword': "તમારો પાસવર્ડ દાખલ કરો",
      'confirmPassword': "પાસવર્ડની પુષ્ટિ કરો",
      'userName': "વપરાશકર્તા નામ",
      'shopName': "દુકાનનું નામ",
      'invalidCredentials': "અમાન્ય વિગતો",
      'connectionError': "કનેક્શન ભૂલ",
      'welcome': "ફરી સ્વાગત છે",
      'enterCredentials': "આગળ વધવા વિગતો દાખલ કરો",
      'dashboard': "ડેશબોર્ડ",
      'sales': "વેચાણ",
      'bills': "બિલો",
      'settings': "સેટિંગ્સ",
      'logout': "લૉગઆઉટ",
      'language': "ભાષા",
      'selectLanguage': "ભાષા પસંદ કરો",
      'forgotPassword': "પાસવર્ડ ભૂલી ગયા?",
      'welcomeBack': "ફરી સ્વાગત છે",
      'phone': "ફોન",
      'owner': "માલિક",
      'profile': "પ્રોફાઇલ",
      'fullName': "પૂરું નામ",
      'emailAddress': "ઈમેલ સરનામું",
      'phoneNumber': "ફોન નંબર",
      'alreadyHaveAccount': "પહેલેથી ખાતું છે?",
      'inventory': "ઇન્વેન્ટરી",
      'reports': "અહેવાલો",
      'customers': "ગ્રાહકો",
      'invoices': "ઇન્વોઇસ",
      'total': "કુલ",
      'refresh': "રીફ્રેશ",
      'today': "આજે",
      'salesByMonth': "મહિના પ્રમાણે વેચાણ",
      'salesByWeek': "અઠવાડિયા પ્રમાણે વેચાણ",
      'salesByYear': "વર્ષ પ્રમાણે વેચાણ",
      'searchQuery': "શોધ પ્રશ્ન",
      'dataUpload': "ડેટા અપલોડ",
      'addSale': "વેચાણ ઉમેરો",
      'totalAmount': "કુલ રકમ",
      'recordedSuccess': "સફળતાપૂર્વક નોંધાયું!",
      'recordedLocally': "સ્થાનિક રીતે સાચવ્યું!",
      'askMeAnything': "કંઈપણ પૂછો...",
      'aiAssistant': "AI સહાયક",
      'performanceOverview': "પ્રદર્શનની ઝાંખી",
      'transactions': "વ્યવહારો",
      'avgOrder': "સરેરાશ ઓર્ડર",
      'products': "ઉત્પાદનો",
      'quickActions': "ઝડપી ક્રિયાઓ",
      'getInsights': "માહિતી મેળવો",
      'week': "અઠવાડિયું",
      'month': "મહિનો",
      'year': "વર્ષ",
      'showing': "બતાવી રહ્યું છે",
      'website': "વેબસાઇટ",
      'shopkeeper': "દુકાનદાર",
      'shareCard': "કાર્ડ શેર કરો",
      'viewBack': "પાછળ જુઓ",
      'viewFront': "આગળ જુઓ",
      'goToDashboard': "ડેશબોર્ડ પર જાઓ",
      'scanToConnect': "જોડાવા સ્કેન કરો",
      'personalInfo': "વ્યક્તિગત માહિતી",
      'shopDetails': "દુકાનની વિગતો",
      'security': "સુરક્ષા",
      'shopType': "દુકાનનો પ્રકાર",
      'taglineOptional': "ટેગલાઇન (વૈકલ્પિક)",
      'websiteOptional': "વેબસાઇટ (વૈકલ્પિક)",
      'analytics': "વિશ્લેષણ",
      'last7Days': "છેલ્લા 7 દિવસ",
      'last30Days': "છેલ્લા 30 દિવસ",
      'thisYear': "આ વર્ષ",
      'noInsights': "કોઈ માહિતી ઉપલબ્ધ નથી",
      'goodMorning': "સુપ્રભાત!",
      'synced': "સિંક થયું",
      'performanceMessage': "આજે તમારી દુકાનનું પ્રદર્શન",
      'salesTrend': "વેચાણનો ટ્રેન્ડ",
      'revenueDistribution': "આવકનું વિતરણ",
      'quantityDistribution': "જથ્થાનું વિતરણ",
      'revenueLeaders': "સૌથી વધુ આવક આપતા ઉત્પાદનો",
      'whatChartShows': "આ ચાર્ટ શું બતાવે છે?",
      'askSimpleLanguage': "સરળ ભાષામાં પૂછો",
      'askButton': "પૂછો",
      'enterProductDetails': "નીચે ઉત્પાદનની વિગતો દાખલ કરો",
      'addProduct': "ઉત્પાદન ઉમેરો",
      'generateBill': "બિલ બનાવો",
      'saveSales': "વેચાણ સાચવો",
      'paymentMethod': "ચુકવણી પદ્ધતિ",
      'cashOffline': "રોકડ / ઑફલાઇન",
      'onlineUPI': "ઑનલાઇન / UPI",
      'confirmPayment': "ચુકવણી મળ્યાની પુષ્ટિ કરો",
      'paymentConfirmed': "ચુકવણીની પુષ્ટિ થઈ",
      'noSalesData': "વેચાણની માહિતી ઉપલબ્ધ નથી",
      'uploadInventory': "ઇન્વેન્ટરી અપલોડ કરો",
      'selectFile': "ફાઇલ પસંદ કરો",
      'upload': "અપલોડ",
      'analyticsOverview': "વિશ્લેષણની ઝાંખી",
      'askToScan': "સ્કેન કરીને ચૂકવણી કરવા ગ્રાહકને કહો",
      'scannedBillTitle': "સ્કેન કરેલું બિલ",
      'askYourQuestion': "તમારો પ્રશ્ન પૂછો",
      'analysisResults': "વિશ્લેષણના પરિણામો",
      'analysisSummary': "વિશ્લેષણનો સારાંશ",
      'detailedData': "વિગતવાર ડેટા",
      'revenueShare': "આવકનો હિસ્સો",
      'topProductsByRevenue': "આવક પ્રમાણે મુખ્ય ઉત્પાદનો",
      'volumeAnalysis': "જથ્થાનું વિશ્લેષણ",
      'unitMovementRadar': "યુનિટ મૂવમેન્ટ રડાર",
      'upwardTrend': "વધતો ટ્રેન્ડ",
      'downwardTrend': "ઘટતો ટ્રેન્ડ",
      'noProductData': "ઉત્પાદન ડેટા નથી",
      'volumeByProduct': "ઉત્પાદન પ્રમાણે જથ્થો",
      'selectDueDate': "ચુકવણીની છેલ્લી તારીખ પસંદ કરો",
      'deadline': "છેલ્લી તારીખ",
      'overdue': "સમયમર્યાદા વટાવી",
      'pendingPayment': "બાકી ચુકવણી",
      'setDeadline': "છેલ્લી તારીખ સેટ કરો",
      'attendance': "હાજરી",
      'addCustomer': "ગ્રાહક ઉમેરો",
      'customerName': "ગ્રાહકનું નામ",
      'newInvoice': "નવું ઇન્વોઇસ",
      'noInvoicesFound': "ઇન્વોઇસ મળ્યાં નથી",
      'noCustomersYet': "હજુ ગ્રાહકો નથી",
      'noProductsYet': "હજુ ઉત્પાદનો નથી",
      'checkIn': "ચેક ઇન",
      'checkOut': "ચેક આઉટ",
      'todayStatus': "આજની સ્થિતિ",
      'history': "ઇતિહાસ",
      'viewAll': "બધું જુઓ",
      'mrp': "મહત્તમ છૂટક કિંમત",
      'rate': "દર",
      'qty': "જથ્થો",
      'amt': "રકમ",
      'description': "વર્ણન",
      'billNo': "બિલ નંબર",
      'date': "તારીખ",
      'time': "સમય",
      'cashier': "કેશિયર",
      'counter': "કાઉન્ટર",
      'cashBill': "રોકડ બિલ",
      'youHaveSaved': "તમે બચાવ્યું",
      'thankYouVisitAgain': "આભાર - ફરી મુલાકાત લો",
      'items': "વસ્તુઓ",
      'cash': "રોકડ",
      'serve': "સેવા",
      'discount': "ડિસ્કાઉન્ટ",
      'expenses': "ખર્ચ",
      'workers': "કામદારો",
      'backup': "બેકઅપ અને પુનઃસ્થાપન",
      'location': "સ્થાન",
      'query': "પ્રશ્ન",
      'giftCard': "ભેટ કાર્ડ",
      'insights': "મહત્ત્વપૂર્ણ જાણકારી",
      'darkMode': "ડાર્ક મોડ",
      'notification': "સૂચનાઓ",
      'about': "વિશે",
      'share': "શેર કરો",
      'help': "મદદ",
      'alwaysHere': "મદદ માટે હંમેશા હાજર",
      'tapToFlip': "QR કોડ જોવા માટે ફેરવવા ટૅપ કરો",
      'tapToSeeFront': "આગળનો ભાગ જોવા ટૅપ કરો",
      'orScan': "અથવા સ્કેન કરો",
      'allContactIncluded': "બધી સંપર્ક માહિતી સામેલ છે",
      'joinCommunity': "અમારા સમુદાયમાં જોડાઓ",
      'uploadData': "ડેટા અપલોડ કરો",
      'askQuestionHint': "પ્રશ્ન પૂછો (ઉદાહરણ: ગયા અઠવાડિયાના વેચાણ બતાવો)",
      'queryTip': "ટિપ: ડેટાબેઝને પ્રશ્ન કરવા માટે ફાઇલ ખાલી રાખો",
      'responseHint': "જવાબ અહીં દેખાશે",
      'avgChange': "સરેરાશ ફેરફાર",
      'revenueLeadersDesc':
          "આ બાર ચાર્ટ પસંદ કરેલા સમયગાળામાં આવક પ્રમાણે ટોચના ઉત્પાદનો બતાવે છે.",
      'salesTrendDesc':
          "આ લાઇન ચાર્ટ તાજેતરના દિવસોના કુલ વેચાણને બતાવે છે અને દુકાનની પ્રગતિ સમજવામાં મદદ કરે છે.",
      'revenueDistributionDesc':
          "આ પાઈ ચાર્ટ કુલ આવકમાં દરેક ઉત્પાદનનો હિસ્સો બતાવે છે.",
      'quantityDistributionDesc':
          "આ રડાર ચાર્ટ દરેક ઉત્પાદનના વેચાયેલા એકમોની સરખામણી કરે છે.",
      'monthlySalesDesc':
          "દર મહિને કુલ વેચાણ નોંધો. વર્ષ દરમિયાનના વલણો અને વધુ વેચાણના સમય ઓળખો.",
      'weeklySalesDesc':
          "છેલ્લા 12 અઠવાડિયાનું વેચાણ જુઓ. સાપ્તાહિક પેટર્ન અને વૃદ્ધિ ઓળખો.",
      'yearlySalesDesc':
          "વિવિધ વર્ષોના કુલ વેચાણની સરખામણી કરો અને લાંબા ગાળાની વૃદ્ધિ જુઓ.",
      'howToUseTitle': "Retail Mind નો ઉપયોગ કેવી રીતે કરવો",
      'step1Title': "1. વેચાણ ઉમેરો",
      'step1Desc': "વેચાણ ઉમેરો આઇકનથી દરેક વેચાણ નોંધો.",
      'step2Title': "2. સ્ટોક સંભાળો",
      'step2Desc': "ઇન્વેન્ટરી સ્ક્રીનથી ઉત્પાદનોનો સ્ટોક ટ્રૅક કરો.",
      'step3Title': "3. અહેવાલો જુઓ",
      'step3Desc': "વિગતવાર વિશ્લેષણ માટે અહેવાલો વિભાગ ખોલો.",
      'step4Title': "4. ભેટ કાર્ડ શેર કરો",
      'step4Desc': "તમારું ડિજિટલ ભેટ કાર્ડ ગ્રાહકોને મોકલો.",
      'step5Title': "5. ચુકવણી સ્વીકારો",
      'step5Desc': "સરળતાથી ચુકવણી મેળવવા તમારો QR કોડ બતાવો.",
      'gotIt': "સમજાયું!",
      'dailyPerformanceRating': "દૈનિક કામગીરીનું મૂલ્યાંકન",
      'salesIncreasedBy': "આજનું વેચાણ આટલું વધ્યું",
      'salesDecreasedBy': "આજનું વેચાણ આટલું ઘટ્યું",
      'bestHour': "શ્રેષ્ઠ કલાક",
      'yesterdayBestProduct': "ગઈકાલનું શ્રેષ્ઠ ઉત્પાદન:",
      'noSales': "વેચાણ નથી",
      'notAvailable': "ઉપલબ્ધ નથી",
      'todaySales': "આજનું વેચાણ",
      'yesterdaySales': "ગઈકાલનું વેચાણ",
      'analysisAmazing':
          "અદ્ભુત! આજે તમે ₹{0} કમાયા, જે ગઈકાલ કરતાં ₹{1} વધુ છે!",
      'analysisProgressing':
          "વેચાણ આગળ વધી રહ્યું છે! આજે ₹{0} નું વેચાણ થયું. ગઈકાલને વટાવવા ₹{1} બાકી છે.",
      'analysisWaiting': "આજના પ્રથમ વેચાણની રાહ છે. આજનો દિવસ ઉત્તમ બનાવીએ!",
      'analysisMatch': "આજે વેચાણ ગઈકાલ જેટલું જ ₹{0} છે! સતત સારું પ્રદર્શન.",
      'goodMorningName': "સુપ્રભાત, {0}! ☀️",
      'goodAfternoonName': "શુભ બપોર, {0}! 🌤️",
      'goodEveningName': "શુભ સાંજ, {0}! 🌙",
      'tapToUploadQr': "QR અપલોડ કરવા ટૅપ કરો",
      'qrUploadFormat': "ગૅલેરીમાંથી PNG / JPG",
      'tripleChannelActive': "ત્રણ-માર્ગીય ઓળખ સક્રિય",
      'listeningForPayments': "UPI, SMS અને સ્ક્રીન સાંભળી રહ્યું છે...",
    },
    'pa': {
      'username': "ਯੂਜ਼ਰਨੇਮ",
      'chooseUsername': "ਯੂਜ਼ਰਨੇਮ ਚੁਣੋ",
      'shopDisplayName': "ਤੁਹਾਡੀ ਦੁਕਾਨ ਦਾ ਦਿਖਾਈ ਦੇਣ ਵਾਲਾ ਨਾਮ",
      'optional': "ਵਿਕਲਪਿਕ",
      'secure': "ਸੁਰੱਖਿਅਤ",
      'resetCustomerPassword': "ਗਾਹਕ ਦਾ ਪਾਸਵਰਡ ਰੀਸੈੱਟ ਕਰੋ",
      'accountEmail': "ਖਾਤੇ ਦੀ ਈਮੇਲ",
      'sendOtp': "OTP ਭੇਜੋ",
      'cancel': "ਰੱਦ ਕਰੋ",
      'enterVerificationCode': "ਤਸਦੀਕ ਕੋਡ ਦਾਖਲ ਕਰੋ",
      'otpSixDigits': "6 ਅੰਕਾਂ ਦਾ OTP",
      'verify': "ਤਸਦੀਕ ਕਰੋ",
      'chooseNewPassword': "ਨਵਾਂ ਪਾਸਵਰਡ ਚੁਣੋ",
      'newPasswordAtLeast8': "ਨਵਾਂ ਪਾਸਵਰਡ (ਘੱਟੋ-ਘੱਟ 8 ਅੱਖਰ)",
      'updatePassword': "ਪਾਸਵਰਡ ਅੱਪਡੇਟ ਕਰੋ",
      'passwordUpdatedLogin':
          "ਪਾਸਵਰਡ ਅੱਪਡੇਟ ਹੋ ਗਿਆ। ਕਿਰਪਾ ਕਰਕੇ ਨਵੇਂ ਪਾਸਵਰਡ ਨਾਲ ਲੌਗਇਨ ਕਰੋ।",
      'registrationSuccessLogin': "ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਸਫਲ! ਕਿਰਪਾ ਕਰਕੇ ਲੌਗਇਨ ਕਰੋ।",
      'welcomeBackShopper': "ਮੁੜ ਸਵਾਗਤ ਹੈ!",
      'createYourAccount': "ਆਪਣਾ ਖਾਤਾ ਬਣਾਓ",
      'phoneTenDigits': "ਫ਼ੋਨ (10 ਅੰਕ)",
      'needAccountRegister': "ਖਾਤਾ ਨਹੀਂ ਹੈ? ਰਜਿਸਟਰ ਕਰੋ",
      'alreadyHaveAccountLogin': "ਪਹਿਲਾਂ ਹੀ ਖਾਤਾ ਹੈ? ਲੌਗਇਨ ਕਰੋ",
      'backToHome': "ਮੁੱਖ ਪੰਨੇ 'ਤੇ ਵਾਪਸ ਜਾਓ",
      'unableRequestOtp': "ਇਸ ਵੇਲੇ ਪਾਸਵਰਡ ਰੀਸੈੱਟ ਦੀ ਬੇਨਤੀ ਨਹੀਂ ਕੀਤੀ ਜਾ ਸਕਦੀ।",
      'enterOtpPrompt': "ਆਪਣੀ ਈਮੇਲ 'ਤੇ ਭੇਜਿਆ 6 ਅੰਕਾਂ ਦਾ OTP ਦਾਖਲ ਕਰੋ।",
      'invalidExpiredOtp': "OTP ਗਲਤ ਹੈ ਜਾਂ ਮਿਆਦ ਪੁੱਗ ਗਈ ਹੈ।",
      'otpUnavailable': "OTP ਦੀ ਤਸਦੀਕ ਨਹੀਂ ਹੋ ਸਕੀ।",
      'passwordMinLength': "ਨਵੇਂ ਪਾਸਵਰਡ ਵਿੱਚ ਘੱਟੋ-ਘੱਟ 8 ਅੱਖਰ ਹੋਣੇ ਚਾਹੀਦੇ ਹਨ।",
      'passwordResetFailed': "ਪਾਸਵਰਡ ਰੀਸੈੱਟ ਅਸਫਲ। ਨਵਾਂ OTP ਮੰਗੋ।",
      'customerLoginInvalidSession': "ਗਾਹਕ ਲੌਗਇਨ ਸੈਸ਼ਨ ਅਵੈਧ ਹੈ।",
      'authenticationFailed': "ਪ੍ਰਮਾਣਿਕਤਾ ਅਸਫਲ",
      'paymentStatusLine': "ਭੁਗਤਾਨ: {method} · {status}",
      'paymentMatchedNotificationHint':
          "ਦੁਕਾਨ ਦੇ ਡਿਵਾਈਸ ਨੋਟੀਫਿਕੇਸ਼ਨ ਨਾਲ ਮਿਲਾਇਆ ਗਿਆ। ਇਹ ਭੁਗਤਾਨ ਪ੍ਰਦਾਤਾ ਦੀ ਪੁਸ਼ਟੀ ਨਹੀਂ ਹੈ; ਮਿਲਾਣ ਲਈ UPI ਹਵਾਲਾ ਸੰਭਾਲੋ।",
      'paymentPendingHint':
          "ਭੁਗਤਾਨ ਦਾ ਮਿਲਾਣ ਹਾਲੇ ਬਾਕੀ ਹੈ। ਸਿਰਫ਼ UPI ਐਪ ਤੋਂ ਵਾਪਸ ਆਉਣ ਨਾਲ ਇਹ ਆਰਡਰ ਭੁਗਤਾਨ ਕੀਤਾ ਹੋਇਆ ਨਹੀਂ ਮੰਨਿਆ ਜਾਂਦਾ।",
      'paymentStatusPaid': "ਭੁਗਤਾਨ ਕੀਤਾ",
      'paymentStatusPending': "ਬਕਾਇਆ",
      'paymentStatusCodDue': "ਨਕਦ ਬਕਾਇਆ",
      'paymentStatusFailed': "ਅਸਫਲ",
      'paymentStatusRefund': "ਵਾਪਸ ਕੀਤਾ",
      'paymentStatusPartial': "ਅੰਸ਼ਕ ਭੁਗਤਾਨ",
      'appTitle': "ਰਿਟੇਲ ਮਾਈਂਡ",
      'usernameOrEmail': 'ਯੂਜ਼ਰਨੇਮ ਜਾਂ ਈਮੇਲ',
      'easyBilling': 'ਸੌਖੀ ਬਿਲਿੰਗ',
      'betterProfits': 'ਵੱਧ ਮੁਨਾਫ਼ਾ',
      'signInGuidance': 'ਸਾਈਨ-ਇਨ ਲਈ ਹਦਾਇਤਾਂ ਸੁਣੋ',
      'voiceInstructionsLanguage': 'ਆਪਣੀ ਭਾਸ਼ਾ ਵਿੱਚ ਆਵਾਜ਼ੀ ਹਦਾਇਤਾਂ ਲਵੋ',
      'playVoiceGuidance': 'ਹਦਾਇਤਾਂ ਸੁਣੋ',
      'stopVoiceGuidance': 'ਬੋਲਣਾ ਬੰਦ ਕਰੋ',
      'continueWithGoogle': 'Google ਨਾਲ ਜਾਰੀ ਰੱਖੋ',
      'noAccount': 'ਖਾਤਾ ਨਹੀਂ ਹੈ?',
      'listenRegisterGuidance': 'ਰਜਿਸਟ੍ਰੇਸ਼ਨ ਲਈ ਹਦਾਇਤਾਂ ਸੁਣੋ',
      'dataProtected': 'ਤੁਹਾਡਾ ਡਾਟਾ ਸੁਰੱਖਿਅਤ ਹੈ',
      'secureAndSafe': 'ਸੁਰੱਖਿਅਤ',
      'growBusinessInLanguage': 'ਆਪਣੀ ਭਾਸ਼ਾ ਵਿੱਚ\nਆਪਣਾ ਕਾਰੋਬਾਰ ਵਧਾਓ',
      'or': 'ਜਾਂ',
      'signingIn': 'ਸਾਈਨ ਇਨ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ',
      'verifyingAccount': 'ਤੁਹਾਡੇ ਖਾਤੇ ਦੀ ਪੁਸ਼ਟੀ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ...',
      'creatingAccount': 'ਤੁਹਾਡਾ ਖਾਤਾ ਬਣਾਇਆ ਜਾ ਰਿਹਾ ਹੈ',
      'registeringShopSync':
          'ਤੁਹਾਡੀ ਦੁਕਾਨ ਨੂੰ ਸੁਰੱਖਿਅਤ ਤਰੀਕੇ ਨਾਲ ਰਜਿਸਟਰ ਕਰਕੇ ਬੈਕਐਂਡ ਨਾਲ ਸਿੰਕ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ',
      'tagline': "ਸਮਾਰਟ ਵਿਸ਼ਲੇਸ਼ਣ ਅਤੇ ਬਿਲਿੰਗ ਪਲੇਟਫਾਰਮ",
      'email': "ਈਮੇਲ",
      'password': "ਪਾਸਵਰਡ",
      'login': "ਲੌਗਇਨ",
      'register': "ਰਜਿਸਟਰ",
      'signIn': "ਸਾਈਨ ਇਨ",
      'createAccount': "ਨਵਾਂ ਖਾਤਾ ਬਣਾਓ",
      'signUp': "ਸਾਈਨ ਅੱਪ",
      'enterEmail': "ਆਪਣਾ ਈਮੇਲ ਦਾਖਲ ਕਰੋ",
      'enterPassword': "ਆਪਣਾ ਪਾਸਵਰਡ ਦਾਖਲ ਕਰੋ",
      'confirmPassword': "ਪਾਸਵਰਡ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ",
      'userName': "ਯੂਜ਼ਰਨੇਮ",
      'shopName': "ਦੁਕਾਨ ਦਾ ਨਾਮ",
      'invalidCredentials': "ਗਲਤ ਵੇਰਵੇ",
      'connectionError': "ਕਨੈਕਸ਼ਨ ਗਲਤੀ",
      'welcome': "ਮੁੜ ਸਵਾਗਤ",
      'enterCredentials': "ਜਾਰੀ ਰੱਖਣ ਲਈ ਜਾਣਕਾਰੀ ਦਾਖਲ ਕਰੋ",
      'dashboard': "ਡੈਸ਼ਬੋਰਡ",
      'sales': "ਵਿਕਰੀ",
      'bills': "ਬਿੱਲ",
      'settings': "ਸੈਟਿੰਗਾਂ",
      'logout': "ਲੌਗ ਆਉਟ",
      'language': "ਭਾਸ਼ਾ",
      'selectLanguage': "ਭਾਸ਼ਾ ਚੁਣੋ",
      'forgotPassword': "ਪਾਸਵਰਡ ਭੁੱਲ ਗਏ?",
      'welcomeBack': "ਮੁੜ ਸਵਾਗਤ",
      'phone': "ਫ਼ੋਨ",
      'owner': "ਮਾਲਕ",
      'profile': "ਪ੍ਰੋਫ਼ਾਈਲ",
      'fullName': "ਪੂਰਾ ਨਾਮ",
      'emailAddress': "ਈਮੇਲ ਪਤਾ",
      'phoneNumber': "ਫ਼ੋਨ ਨੰਬਰ",
      'alreadyHaveAccount': "ਪਹਿਲਾਂ ਹੀ ਖਾਤਾ ਹੈ?",
      'inventory': "ਸਟਾਕ",
      'reports': "ਰਿਪੋਰਟਾਂ",
      'customers': "ਗਾਹਕ",
      'invoices': "ਚਲਾਨ",
      'total': "ਕੁੱਲ",
      'refresh': "ਤਾਜ਼ਾ ਕਰੋ",
      'today': "ਅੱਜ",
      'salesByMonth': "ਮਹੀਨੇ ਮੁਤਾਬਕ ਵਿਕਰੀ",
      'salesByWeek': "ਹਫ਼ਤੇ ਮੁਤਾਬਕ ਵਿਕਰੀ",
      'salesByYear': "ਸਾਲ ਮੁਤਾਬਕ ਵਿਕਰੀ",
      'searchQuery': "ਖੋਜ ਸਵਾਲ",
      'dataUpload': "ਡਾਟਾ ਅੱਪਲੋਡ",
      'addSale': "ਵਿਕਰੀ ਜੋੜੋ",
      'totalAmount': "ਕੁੱਲ ਰਕਮ",
      'recordedSuccess': "ਸਫਲਤਾਪੂਰਵਕ ਦਰਜ ਕੀਤਾ ਗਿਆ!",
      'recordedLocally': "ਸਥਾਨਕ ਤੌਰ 'ਤੇ ਸੰਭਾਲਿਆ!",
      'askMeAnything': "ਕੁਝ ਵੀ ਪੁੱਛੋ...",
      'aiAssistant': "AI ਸਹਾਇਕ",
      'performanceOverview': "ਕਾਰਗੁਜ਼ਾਰੀ ਦੀ ਝਲਕ",
      'transactions': "ਲੈਣ-ਦੇਣ",
      'avgOrder': "ਔਸਤ ਆਰਡਰ",
      'products': "ਉਤਪਾਦ",
      'quickActions': "ਤੇਜ਼ ਕਾਰਵਾਈਆਂ",
      'getInsights': "ਸੂਝ ਪ੍ਰਾਪਤ ਕਰੋ",
      'week': "ਹਫ਼ਤਾ",
      'month': "ਮਹੀਨਾ",
      'year': "ਸਾਲ",
      'showing': "ਦਿਖਾ ਰਿਹਾ ਹੈ",
      'website': "ਵੈੱਬਸਾਈਟ",
      'shopkeeper': "ਦੁਕਾਨਦਾਰ",
      'shareCard': "ਕਾਰਡ ਸਾਂਝਾ ਕਰੋ",
      'viewBack': "ਪਿੱਛੇ ਵੇਖੋ",
      'viewFront': "ਅੱਗੇ ਵੇਖੋ",
      'goToDashboard': "ਡੈਸ਼ਬੋਰਡ 'ਤੇ ਜਾਓ",
      'scanToConnect': "ਜੁੜਨ ਲਈ ਸਕੈਨ ਕਰੋ",
      'personalInfo': "ਨਿੱਜੀ ਜਾਣਕਾਰੀ",
      'shopDetails': "ਦੁਕਾਨ ਦੇ ਵੇਰਵੇ",
      'security': "ਸੁਰੱਖਿਆ",
      'shopType': "ਦੁਕਾਨ ਦੀ ਕਿਸਮ",
      'taglineOptional': "ਟੈਗਲਾਈਨ (ਵਿਕਲਪਿਕ)",
      'websiteOptional': "ਵੈੱਬਸਾਈਟ (ਵਿਕਲਪਿਕ)",
      'analytics': "ਵਿਸ਼ਲੇਸ਼ਣ",
      'last7Days': "ਪਿਛਲੇ 7 ਦਿਨ",
      'last30Days': "ਪਿਛਲੇ 30 ਦਿਨ",
      'thisYear': "ਇਹ ਸਾਲ",
      'noInsights': "ਕੋਈ ਸੂਝ ਉਪਲਬਧ ਨਹੀਂ",
      'goodMorning': "ਸ਼ੁਭ ਸਵੇਰ!",
      'synced': "ਸਿੰਕ ਹੋ ਗਿਆ",
      'performanceMessage': "ਅੱਜ ਤੁਹਾਡੀ ਦੁਕਾਨ ਦੀ ਕਾਰਗੁਜ਼ਾਰੀ",
      'salesTrend': "ਵਿਕਰੀ ਦਾ ਰੁਝਾਨ",
      'revenueDistribution': "ਆਮਦਨ ਦੀ ਵੰਡ",
      'quantityDistribution': "ਮਾਤਰਾ ਦੀ ਵੰਡ",
      'revenueLeaders': "ਵੱਧ ਆਮਦਨ ਵਾਲੇ ਉਤਪਾਦ",
      'whatChartShows': "ਇਹ ਚਾਰਟ ਕੀ ਦਿਖਾਉਂਦਾ ਹੈ?",
      'askSimpleLanguage': "ਸਧਾਰਨ ਭਾਸ਼ਾ ਵਿੱਚ ਪੁੱਛੋ",
      'askButton': "ਪੁੱਛੋ",
      'enterProductDetails': "ਹੇਠਾਂ ਉਤਪਾਦਾਂ ਦੇ ਵੇਰਵੇ ਦਾਖਲ ਕਰੋ",
      'addProduct': "ਉਤਪਾਦ ਜੋੜੋ",
      'generateBill': "ਬਿੱਲ ਬਣਾਓ",
      'saveSales': "ਵਿਕਰੀ ਸੰਭਾਲੋ",
      'paymentMethod': "ਭੁਗਤਾਨ ਦਾ ਤਰੀਕਾ",
      'cashOffline': "ਨਕਦ / ਆਫ਼ਲਾਈਨ",
      'onlineUPI': "ਆਨਲਾਈਨ / UPI",
      'confirmPayment': "ਭੁਗਤਾਨ ਮਿਲਣ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ",
      'paymentConfirmed': "ਭੁਗਤਾਨ ਦੀ ਪੁਸ਼ਟੀ ਹੋ ਗਈ",
      'noSalesData': "ਵਿਕਰੀ ਦਾ ਡਾਟਾ ਉਪਲਬਧ ਨਹੀਂ",
      'uploadInventory': "ਸਟਾਕ ਅੱਪਲੋਡ ਕਰੋ",
      'selectFile': "ਫ਼ਾਈਲ ਚੁਣੋ",
      'upload': "ਅੱਪਲੋਡ",
      'analyticsOverview': "ਵਿਸ਼ਲੇਸ਼ਣ ਦੀ ਝਲਕ",
      'askToScan': "ਸਕੈਨ ਕਰਕੇ ਭੁਗਤਾਨ ਕਰਨ ਲਈ ਗਾਹਕ ਨੂੰ ਕਹੋ",
      'scannedBillTitle': "ਸਕੈਨ ਕੀਤਾ ਬਿੱਲ",
      'askYourQuestion': "ਆਪਣਾ ਸਵਾਲ ਪੁੱਛੋ",
      'analysisResults': "ਵਿਸ਼ਲੇਸ਼ਣ ਦੇ ਨਤੀਜੇ",
      'analysisSummary': "ਵਿਸ਼ਲੇਸ਼ਣ ਦਾ ਸਾਰ",
      'detailedData': "ਵਿਸਥਾਰਿਤ ਡਾਟਾ",
      'revenueShare': "ਆਮਦਨ ਦਾ ਹਿੱਸਾ",
      'topProductsByRevenue': "ਆਮਦਨ ਅਨੁਸਾਰ ਮੁੱਖ ਉਤਪਾਦ",
      'volumeAnalysis': "ਮਾਤਰਾ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ",
      'unitMovementRadar': "ਯੂਨਿਟ ਮੂਵਮੈਂਟ ਰਡਾਰ",
      'upwardTrend': "ਵਧਦਾ ਰੁਝਾਨ",
      'downwardTrend': "ਘਟਦਾ ਰੁਝਾਨ",
      'noProductData': "ਉਤਪਾਦ ਦਾ ਡਾਟਾ ਨਹੀਂ",
      'volumeByProduct': "ਉਤਪਾਦ ਮੁਤਾਬਕ ਮਾਤਰਾ",
      'selectDueDate': "ਆਖ਼ਰੀ ਤਾਰੀਖ ਚੁਣੋ",
      'deadline': "ਆਖ਼ਰੀ ਤਾਰੀਖ",
      'overdue': "ਮਿਆਦ ਲੰਘ ਗਈ",
      'pendingPayment': "ਬਕਾਇਆ ਭੁਗਤਾਨ",
      'setDeadline': "ਆਖ਼ਰੀ ਤਾਰੀਖ ਨਿਰਧਾਰਤ ਕਰੋ",
      'attendance': "ਹਾਜ਼ਰੀ",
      'addCustomer': "ਗਾਹਕ ਜੋੜੋ",
      'customerName': "ਗਾਹਕ ਦਾ ਨਾਮ",
      'newInvoice': "ਨਵਾਂ ਇਨਵੌਇਸ",
      'noInvoicesFound': "ਕੋਈ ਇਨਵੌਇਸ ਨਹੀਂ ਮਿਲਿਆ",
      'noCustomersYet': "ਹਾਲੇ ਕੋਈ ਗਾਹਕ ਨਹੀਂ",
      'noProductsYet': "ਹਾਲੇ ਕੋਈ ਉਤਪਾਦ ਨਹੀਂ",
      'checkIn': "ਚੈੱਕ ਇਨ",
      'checkOut': "ਚੈੱਕ ਆਉਟ",
      'todayStatus': "ਅੱਜ ਦੀ ਸਥਿਤੀ",
      'history': "ਇਤਿਹਾਸ",
      'viewAll': "ਸਭ ਵੇਖੋ",
      'mrp': "ਵੱਧ ਤੋਂ ਵੱਧ ਖੁਦਰਾ ਕੀਮਤ",
      'rate': "ਦਰ",
      'qty': "ਮਾਤਰਾ",
      'amt': "ਰਕਮ",
      'description': "ਵੇਰਵਾ",
      'billNo': "ਬਿੱਲ ਨੰਬਰ",
      'date': "ਤਾਰੀਖ",
      'time': "ਸਮਾਂ",
      'cashier': "ਕੈਸ਼ੀਅਰ",
      'counter': "ਕਾਊਂਟਰ",
      'cashBill': "ਨਕਦ ਬਿੱਲ",
      'youHaveSaved': "ਤੁਸੀਂ ਬਚਾਇਆ",
      'thankYouVisitAgain': "ਧੰਨਵਾਦ - ਮੁੜ ਆਓ",
      'items': "ਚੀਜ਼ਾਂ",
      'cash': "ਨਕਦ",
      'serve': "ਸੇਵਾ",
      'discount': "ਛੂਟ",
      'expenses': "ਖਰਚੇ",
      'workers': "ਕਰਮਚਾਰੀ",
      'backup': "ਬੈਕਅੱਪ ਅਤੇ ਰੀਸਟੋਰ",
      'location': "ਟਿਕਾਣਾ",
      'query': "ਸਵਾਲ",
      'giftCard': "ਤੋਹਫ਼ਾ ਕਾਰਡ",
      'insights': "ਮਹੱਤਵਪੂਰਨ ਜਾਣਕਾਰੀ",
      'darkMode': "ਡਾਰਕ ਮੋਡ",
      'notification': "ਸੂਚਨਾਵਾਂ",
      'about': "ਬਾਰੇ",
      'share': "ਸਾਂਝਾ ਕਰੋ",
      'help': "ਮਦਦ",
      'alwaysHere': "ਮਦਦ ਲਈ ਹਮੇਸ਼ਾ ਹਾਜ਼ਰ",
      'tapToFlip': "QR ਕੋਡ ਲਈ ਪਲਟਣ ਵਾਸਤੇ ਟੈਪ ਕਰੋ",
      'tapToSeeFront': "ਅੱਗੇ ਵਾਲਾ ਹਿੱਸਾ ਦੇਖਣ ਲਈ ਟੈਪ ਕਰੋ",
      'orScan': "ਜਾਂ ਸਕੈਨ ਕਰੋ",
      'allContactIncluded': "ਸਾਰੀ ਸੰਪਰਕ ਜਾਣਕਾਰੀ ਸ਼ਾਮਲ ਹੈ",
      'joinCommunity': "ਸਾਡੇ ਭਾਈਚਾਰੇ ਨਾਲ ਜੁੜੋ",
      'uploadData': "ਡਾਟਾ ਅੱਪਲੋਡ ਕਰੋ",
      'askQuestionHint': "ਸਵਾਲ ਪੁੱਛੋ (ਉਦਾਹਰਨ: ਪਿਛਲੇ ਹਫ਼ਤੇ ਦੀ ਵਿਕਰੀ ਦਿਖਾਓ)",
      'queryTip': "ਸੁਝਾਅ: ਡਾਟਾਬੇਸ ਤੋਂ ਪੁੱਛਣ ਲਈ ਫ਼ਾਈਲ ਖਾਲੀ ਛੱਡੋ",
      'responseHint': "ਜਵਾਬ ਇੱਥੇ ਦਿਖੇਗਾ",
      'avgChange': "ਔਸਤ ਬਦਲਾਅ",
      'revenueLeadersDesc':
          "ਇਹ ਬਾਰ ਚਾਰਟ ਚੁਣੇ ਸਮੇਂ ਦੌਰਾਨ ਆਮਦਨ ਮੁਤਾਬਕ ਸਭ ਤੋਂ ਵਧੀਆ ਉਤਪਾਦ ਦਿਖਾਉਂਦਾ ਹੈ।",
      'salesTrendDesc':
          "ਇਹ ਲਾਈਨ ਚਾਰਟ ਹਾਲੀਆ ਦਿਨਾਂ ਦੀ ਕੁੱਲ ਵਿਕਰੀ ਦਿਖਾਉਂਦਾ ਹੈ ਅਤੇ ਦੁਕਾਨ ਦੀ ਤਰੱਕੀ ਸਮਝਣ ਵਿੱਚ ਮਦਦ ਕਰਦਾ ਹੈ।",
      'revenueDistributionDesc':
          "ਇਹ ਪਾਈ ਚਾਰਟ ਕੁੱਲ ਆਮਦਨ ਵਿੱਚ ਹਰ ਉਤਪਾਦ ਦਾ ਹਿੱਸਾ ਦਿਖਾਉਂਦਾ ਹੈ।",
      'quantityDistributionDesc':
          "ਇਹ ਰਡਾਰ ਚਾਰਟ ਹਰ ਉਤਪਾਦ ਦੀ ਵਿਕੀਆਂ ਇਕਾਈਆਂ ਦੀ ਤੁਲਨਾ ਕਰਦਾ ਹੈ।",
      'monthlySalesDesc':
          "ਹਰ ਮਹੀਨੇ ਦੀ ਕੁੱਲ ਵਿਕਰੀ ਵੇਖੋ। ਸਾਲ ਦੇ ਰੁਝਾਨ ਅਤੇ ਸਭ ਤੋਂ ਵੱਧ ਵਿਕਰੀ ਵਾਲੇ ਸਮੇਂ ਪਛਾਣੋ।",
      'weeklySalesDesc':
          "ਪਿਛਲੇ 12 ਹਫ਼ਤਿਆਂ ਦੀ ਵਿਕਰੀ ਵੇਖੋ। ਹਫ਼ਤਾਵਾਰ ਰੁਝਾਨ ਅਤੇ ਵਾਧਾ ਪਛਾਣੋ।",
      'yearlySalesDesc':
          "ਵੱਖ-ਵੱਖ ਸਾਲਾਂ ਦੀ ਕੁੱਲ ਵਿਕਰੀ ਦੀ ਤੁਲਨਾ ਕਰਕੇ ਲੰਬੇ ਸਮੇਂ ਦਾ ਵਾਧਾ ਵੇਖੋ।",
      'howToUseTitle': "Retail Mind ਦੀ ਵਰਤੋਂ ਕਿਵੇਂ ਕਰੀਏ",
      'step1Title': "1. ਵਿਕਰੀ ਸ਼ਾਮਲ ਕਰੋ",
      'step1Desc': "ਵਿਕਰੀ ਸ਼ਾਮਲ ਕਰੋ ਆਈਕਨ ਰਾਹੀਂ ਹਰ ਵਿਕਰੀ ਦਰਜ ਕਰੋ।",
      'step2Title': "2. ਸਟਾਕ ਸੰਭਾਲੋ",
      'step2Desc': "ਇਨਵੈਂਟਰੀ ਸਕ੍ਰੀਨ ਰਾਹੀਂ ਉਤਪਾਦਾਂ ਦਾ ਸਟਾਕ ਦੇਖੋ।",
      'step3Title': "3. ਰਿਪੋਰਟਾਂ ਵੇਖੋ",
      'step3Desc': "ਵਿਸਥਾਰਪੂਰਵਕ ਵਿਸ਼ਲੇਸ਼ਣ ਲਈ ਰਿਪੋਰਟਾਂ ਵਾਲਾ ਭਾਗ ਖੋਲ੍ਹੋ।",
      'step4Title': "4. ਤੋਹਫ਼ਾ ਕਾਰਡ ਸਾਂਝਾ ਕਰੋ",
      'step4Desc': "ਆਪਣਾ ਡਿਜ਼ਿਟਲ ਤੋਹਫ਼ਾ ਕਾਰਡ ਗਾਹਕਾਂ ਨੂੰ ਭੇਜੋ।",
      'step5Title': "5. ਭੁਗਤਾਨ ਸਵੀਕਾਰ ਕਰੋ",
      'step5Desc': "ਭੁਗਤਾਨ ਲੈਣ ਲਈ ਆਪਣਾ QR ਕੋਡ ਦਿਖਾਓ।",
      'gotIt': "ਸਮਝ ਆ ਗਿਆ!",
      'dailyPerformanceRating': "ਰੋਜ਼ਾਨਾ ਕਾਰਗੁਜ਼ਾਰੀ ਮੁਲਾਂਕਣ",
      'salesIncreasedBy': "ਅੱਜ ਦੀ ਵਿਕਰੀ ਇੰਨੀ ਵਧੀ",
      'salesDecreasedBy': "ਅੱਜ ਦੀ ਵਿਕਰੀ ਇੰਨੀ ਘਟੀ",
      'bestHour': "ਸਭ ਤੋਂ ਵਧੀਆ ਘੰਟਾ",
      'yesterdayBestProduct': "ਕੱਲ੍ਹ ਦਾ ਸਭ ਤੋਂ ਵਧੀਆ ਉਤਪਾਦ:",
      'noSales': "ਕੋਈ ਵਿਕਰੀ ਨਹੀਂ",
      'notAvailable': "ਉਪਲਬਧ ਨਹੀਂ",
      'todaySales': "ਅੱਜ ਦੀ ਵਿਕਰੀ",
      'yesterdaySales': "ਕੱਲ੍ਹ ਦੀ ਵਿਕਰੀ",
      'analysisAmazing':
          "ਸ਼ਾਨਦਾਰ! ਅੱਜ ਤੁਸੀਂ ₹{0} ਕਮਾਏ, ਜੋ ਕੱਲ੍ਹ ਨਾਲੋਂ ₹{1} ਵੱਧ ਹਨ!",
      'analysisProgressing':
          "ਵਿਕਰੀ ਵਿੱਚ ਸੁਧਾਰ ਹੈ! ਅੱਜ ₹{0} ਦੀ ਵਿਕਰੀ ਹੋਈ। ਕੱਲ੍ਹ ਨੂੰ ਪਾਰ ਕਰਨ ਲਈ ₹{1} ਹੋਰ ਚਾਹੀਦੇ ਹਨ।",
      'analysisWaiting': "ਅੱਜ ਦੀ ਪਹਿਲੀ ਵਿਕਰੀ ਦੀ ਉਡੀਕ ਹੈ। ਆਓ ਦਿਨ ਵਧੀਆ ਬਣਾਈਏ!",
      'analysisMatch': "ਅੱਜ ਦੀ ਵਿਕਰੀ ਕੱਲ੍ਹ ਵਾਂਗ ਹੀ ₹{0} ਹੈ! ਲਗਾਤਾਰ ਵਧੀਆ ਕੰਮ।",
      'goodMorningName': "ਸਤ ਸ੍ਰੀ ਅਕਾਲ, {0}! ☀️",
      'goodAfternoonName': "ਸ਼ੁਭ ਦੁਪਹਿਰ, {0}! 🌤️",
      'goodEveningName': "ਸ਼ੁਭ ਸ਼ਾਮ, {0}! 🌙",
      'tapToUploadQr': "QR ਅੱਪਲੋਡ ਕਰਨ ਲਈ ਟੈਪ ਕਰੋ",
      'qrUploadFormat': "ਗੈਲਰੀ ਤੋਂ PNG / JPG",
      'tripleChannelActive': "ਤਿੰਨ-ਚੈਨਲ ਪਛਾਣ ਚਾਲੂ ਹੈ",
      'listeningForPayments': "UPI, SMS ਅਤੇ ਸਕ੍ਰੀਨ ਨੂੰ ਸੁਣ ਰਿਹਾ ਹੈ...",
    },
    'bn': {
      'username': "ব্যবহারকারীর নাম",
      'chooseUsername': "একটি ব্যবহারকারীর নাম বেছে নিন",
      'shopDisplayName': "আপনার দোকানের প্রদর্শিত নাম",
      'optional': "ঐচ্ছিক",
      'secure': "সুরক্ষিত",
      'resetCustomerPassword': "গ্রাহকের পাসওয়ার্ড রিসেট করুন",
      'accountEmail': "অ্যাকাউন্টের ইমেল",
      'sendOtp': "OTP পাঠান",
      'cancel': "বাতিল",
      'enterVerificationCode': "যাচাইকরণ কোড লিখুন",
      'otpSixDigits': "৬ সংখ্যার OTP",
      'verify': "যাচাই করুন",
      'chooseNewPassword': "নতুন পাসওয়ার্ড বেছে নিন",
      'newPasswordAtLeast8': "নতুন পাসওয়ার্ড (কমপক্ষে ৮ অক্ষর)",
      'updatePassword': "পাসওয়ার্ড আপডেট করুন",
      'passwordUpdatedLogin':
          "পাসওয়ার্ড আপডেট হয়েছে। নতুন পাসওয়ার্ড দিয়ে লগইন করুন।",
      'registrationSuccessLogin': "নিবন্ধন সফল! অনুগ্রহ করে লগইন করুন।",
      'welcomeBackShopper': "আবার স্বাগতম!",
      'createYourAccount': "আপনার অ্যাকাউন্ট তৈরি করুন",
      'phoneTenDigits': "ফোন (১০ সংখ্যা)",
      'needAccountRegister': "অ্যাকাউন্ট নেই? নিবন্ধন করুন",
      'alreadyHaveAccountLogin': "ইতিমধ্যে অ্যাকাউন্ট আছে? লগইন করুন",
      'backToHome': "হোমে ফিরে যান",
      'unableRequestOtp':
          "এই মুহূর্তে পাসওয়ার্ড রিসেটের অনুরোধ করা যাচ্ছে না।",
      'enterOtpPrompt': "আপনার ইমেলে পাঠানো ৬ সংখ্যার OTP লিখুন।",
      'invalidExpiredOtp': "OTP ভুল অথবা মেয়াদ শেষ হয়েছে।",
      'otpUnavailable': "OTP যাচাই করা যায়নি।",
      'passwordMinLength': "নতুন পাসওয়ার্ডে কমপক্ষে ৮টি অক্ষর থাকতে হবে।",
      'passwordResetFailed':
          "পাসওয়ার্ড রিসেট ব্যর্থ। নতুন OTP-এর অনুরোধ করুন।",
      'customerLoginInvalidSession': "গ্রাহক লগইন সেশনটি অবৈধ।",
      'authenticationFailed': "প্রমাণীকরণ ব্যর্থ",
      'paymentStatusLine': "পেমেন্ট: {method} · {status}",
      'paymentMatchedNotificationHint':
          "দোকানের ডিভাইসের বিজ্ঞপ্তির সঙ্গে মেলানো হয়েছে। এটি পেমেন্ট প্রদানকারীর নিশ্চিতকরণ নয়; মিলিয়ে দেখার জন্য UPI রেফারেন্স সংরক্ষণ করুন।",
      'paymentPendingHint':
          "পেমেন্টের মিল নিশ্চিতকরণ এখনও বাকি। শুধু UPI অ্যাপ থেকে ফিরে এলেই এই অর্ডার পেমেন্ট করা হয়েছে বলে গণ্য হয় না।",
      'paymentStatusPaid': "পরিশোধিত",
      'paymentStatusPending': "বাকি",
      'paymentStatusCodDue': "নগদ বাকি",
      'paymentStatusFailed': "ব্যর্থ",
      'paymentStatusRefund': "ফেরত দেওয়া",
      'paymentStatusPartial': "আংশিক পরিশোধ",
      'appTitle': "রিটেল মাইন্ড",
      'usernameOrEmail': 'ব্যবহারকারীর নাম বা ইমেল',
      'easyBilling': 'সহজ বিলিং',
      'betterProfits': 'বেশি লাভ',
      'signInGuidance': 'সাইন-ইন নির্দেশনা শুনুন',
      'voiceInstructionsLanguage': 'আপনার ভাষায় কণ্ঠস্বরের নির্দেশনা পান',
      'playVoiceGuidance': 'নির্দেশনা শুনুন',
      'stopVoiceGuidance': 'কথা বলা বন্ধ করুন',
      'continueWithGoogle': 'Google দিয়ে চালিয়ে যান',
      'noAccount': 'অ্যাকাউন্ট নেই?',
      'listenRegisterGuidance': 'নিবন্ধনের নির্দেশনা শুনুন',
      'dataProtected': 'আপনার ডেটা সুরক্ষিত',
      'secureAndSafe': 'নিরাপদ ও সুরক্ষিত',
      'growBusinessInLanguage': 'আপনার ভাষায়\nআপনার ব্যবসা বাড়ান',
      'or': 'অথবা',
      'signingIn': 'সাইন ইন করা হচ্ছে',
      'verifyingAccount': 'আপনার অ্যাকাউন্ট যাচাই করা হচ্ছে...',
      'creatingAccount': 'আপনার অ্যাকাউন্ট তৈরি করা হচ্ছে',
      'registeringShopSync':
          'আপনার দোকান নিরাপদে নিবন্ধিত করে ব্যাকএন্ডের সঙ্গে সিঙ্ক করা হচ্ছে',
      'tagline': "স্মার্ট বিশ্লেষণ ও বিলিং প্ল্যাটফর্ম",
      'email': "ইমেল",
      'password': "পাসওয়ার্ড",
      'login': "লগইন",
      'register': "নিবন্ধন",
      'signIn': "সাইন ইন",
      'createAccount': "নতুন অ্যাকাউন্ট তৈরি করুন",
      'signUp': "সাইন আপ",
      'enterEmail': "আপনার ইমেল লিখুন",
      'enterPassword': "আপনার পাসওয়ার্ড লিখুন",
      'confirmPassword': "পাসওয়ার্ড নিশ্চিত করুন",
      'userName': "ব্যবহারকারীর নাম",
      'shopName': "দোকানের নাম",
      'invalidCredentials': "ভুল তথ্য",
      'connectionError': "সংযোগ ত্রুটি",
      'welcome': "আবার স্বাগতম",
      'enterCredentials': "চালিয়ে যেতে আপনার তথ্য লিখুন",
      'dashboard': "ড্যাশবোর্ড",
      'sales': "বিক্রয়",
      'bills': "বিল",
      'settings': "সেটিংস",
      'logout': "লগআউট",
      'language': "ভাষা",
      'selectLanguage': "ভাষা নির্বাচন করুন",
      'forgotPassword': "পাসওয়ার্ড ভুলে গেছেন?",
      'welcomeBack': "আবার স্বাগতম",
      'phone': "ফোন",
      'owner': "মালিক",
      'profile': "প্রোফাইল",
      'fullName': "পূর্ণ নাম",
      'emailAddress': "ইমেল ঠিকানা",
      'phoneNumber': "ফোন নম্বর",
      'alreadyHaveAccount': "ইতিমধ্যে অ্যাকাউন্ট আছে?",
      'inventory': "মজুত",
      'reports': "রিপোর্ট",
      'customers': "গ্রাহক",
      'invoices': "ইনভয়েস",
      'total': "মোট",
      'refresh': "রিফ্রেশ",
      'today': "আজ",
      'salesByMonth': "মাস অনুযায়ী বিক্রয়",
      'salesByWeek': "সপ্তাহ অনুযায়ী বিক্রয়",
      'salesByYear': "বছর অনুযায়ী বিক্রয়",
      'searchQuery': "অনুসন্ধানের প্রশ্ন",
      'dataUpload': "ডেটা আপলোড",
      'addSale': "বিক্রয় যোগ করুন",
      'totalAmount': "মোট পরিমাণ",
      'recordedSuccess': "সফলভাবে নথিভুক্ত হয়েছে!",
      'recordedLocally': "স্থানীয়ভাবে সংরক্ষিত হয়েছে!",
      'askMeAnything': "যেকোনো কিছু জিজ্ঞাসা করুন...",
      'aiAssistant': "AI সহকারী",
      'performanceOverview': "কর্মক্ষমতার সারাংশ",
      'transactions': "লেনদেন",
      'avgOrder': "গড় অর্ডার",
      'products': "পণ্য",
      'quickActions': "দ্রুত কাজ",
      'getInsights': "অন্তর্দৃষ্টি পান",
      'week': "সপ্তাহ",
      'month': "মাস",
      'year': "বছর",
      'showing': "দেখানো হচ্ছে",
      'website': "ওয়েবসাইট",
      'shopkeeper': "দোকানদার",
      'shareCard': "কার্ড শেয়ার করুন",
      'viewBack': "পেছন দেখুন",
      'viewFront': "সামনের দিক দেখুন",
      'goToDashboard': "ড্যাশবোর্ডে যান",
      'scanToConnect': "সংযোগ করতে স্ক্যান করুন",
      'personalInfo': "ব্যক্তিগত তথ্য",
      'shopDetails': "দোকানের বিবরণ",
      'security': "নিরাপত্তা",
      'shopType': "দোকানের ধরন",
      'taglineOptional': "ট্যাগলাইন (ঐচ্ছিক)",
      'websiteOptional': "ওয়েবসাইট (ঐচ্ছিক)",
      'analytics': "বিশ্লেষণ",
      'last7Days': "গত ৭ দিন",
      'last30Days': "গত ৩০ দিন",
      'thisYear': "এই বছর",
      'noInsights': "কোনো অন্তর্দৃষ্টি নেই",
      'goodMorning': "সুপ্রভাত!",
      'synced': "সিঙ্ক হয়েছে",
      'performanceMessage': "আজ আপনার দোকানের কর্মক্ষমতা",
      'salesTrend': "বিক্রয়ের প্রবণতা",
      'revenueDistribution': "আয়ের বণ্টন",
      'quantityDistribution': "পরিমাণের বণ্টন",
      'revenueLeaders': "সর্বাধিক আয়কারী পণ্য",
      'whatChartShows': "এই চার্ট কী দেখায়?",
      'askSimpleLanguage': "সহজ ভাষায় জিজ্ঞাসা করুন",
      'askButton': "জিজ্ঞাসা করুন",
      'enterProductDetails': "নিচে পণ্যের বিবরণ লিখুন",
      'addProduct': "পণ্য যোগ করুন",
      'generateBill': "বিল তৈরি করুন",
      'saveSales': "বিক্রয় সংরক্ষণ করুন",
      'paymentMethod': "পেমেন্ট পদ্ধতি",
      'cashOffline': "নগদ / অফলাইন",
      'onlineUPI': "অনলাইন / UPI",
      'confirmPayment': "পেমেন্ট পাওয়া নিশ্চিত করুন",
      'paymentConfirmed': "পেমেন্ট নিশ্চিত",
      'noSalesData': "বিক্রয়ের তথ্য নেই",
      'uploadInventory': "মজুত আপলোড করুন",
      'selectFile': "ফাইল নির্বাচন করুন",
      'upload': "আপলোড",
      'analyticsOverview': "বিশ্লেষণের সারাংশ",
      'askToScan': "স্ক্যান করে পেমেন্ট করতে গ্রাহককে বলুন",
      'scannedBillTitle': "স্ক্যান করা বিল",
      'askYourQuestion': "আপনার প্রশ্ন করুন",
      'analysisResults': "বিশ্লেষণের ফলাফল",
      'analysisSummary': "বিশ্লেষণের সারাংশ",
      'detailedData': "বিস্তারিত ডেটা",
      'revenueShare': "আয়ের অংশ",
      'topProductsByRevenue': "আয় অনুযায়ী শীর্ষ পণ্য",
      'volumeAnalysis': "পরিমাণ বিশ্লেষণ",
      'unitMovementRadar': "ইউনিট চলাচল রাডার",
      'upwardTrend': "ঊর্ধ্বমুখী প্রবণতা",
      'downwardTrend': "নিম্নমুখী প্রবণতা",
      'noProductData': "পণ্যের ডেটা নেই",
      'volumeByProduct': "পণ্য অনুযায়ী পরিমাণ",
      'selectDueDate': "শেষ তারিখ নির্বাচন করুন",
      'deadline': "শেষ তারিখ",
      'overdue': "সময়সীমা পেরিয়েছে",
      'pendingPayment': "বকেয়া পেমেন্ট",
      'setDeadline': "শেষ তারিখ সেট করুন",
      'attendance': "উপস্থিতি",
      'addCustomer': "গ্রাহক যোগ করুন",
      'customerName': "গ্রাহকের নাম",
      'newInvoice': "নতুন ইনভয়েস",
      'noInvoicesFound': "কোনো ইনভয়েস পাওয়া যায়নি",
      'noCustomersYet': "এখনও কোনো গ্রাহক নেই",
      'noProductsYet': "এখনও কোনো পণ্য নেই",
      'checkIn': "চেক ইন",
      'checkOut': "চেক আউট",
      'todayStatus': "আজকের অবস্থা",
      'history': "ইতিহাস",
      'viewAll': "সব দেখুন",
      'mrp': "সর্বোচ্চ খুচরা মূল্য",
      'rate': "দর",
      'qty': "পরিমাণ",
      'amt': "মোট",
      'description': "বিবরণ",
      'billNo': "বিল নম্বর",
      'date': "তারিখ",
      'time': "সময়",
      'cashier': "ক্যাশিয়ার",
      'counter': "কাউন্টার",
      'cashBill': "নগদ বিল",
      'youHaveSaved': "আপনি সাশ্রয় করেছেন",
      'thankYouVisitAgain': "ধন্যবাদ - আবার আসুন",
      'items': "আইটেম",
      'cash': "নগদ",
      'serve': "পরিষেবা",
      'discount': "ছাড়",
      'expenses': "খরচ",
      'workers': "কর্মী",
      'backup': "ব্যাকআপ ও পুনরুদ্ধার",
      'location': "অবস্থান",
      'query': "প্রশ্ন",
      'giftCard': "উপহার কার্ড",
      'insights': "গুরুত্বপূর্ণ তথ্য",
      'darkMode': "ডার্ক মোড",
      'notification': "বিজ্ঞপ্তি",
      'about': "সম্পর্কে",
      'share': "শেয়ার করুন",
      'help': "সাহায্য",
      'alwaysHere': "সাহায্যের জন্য সবসময় আছি",
      'tapToFlip': "QR কোড দেখতে উল্টাতে ট্যাপ করুন",
      'tapToSeeFront': "সামনের দিক দেখতে ট্যাপ করুন",
      'orScan': "অথবা স্ক্যান করুন",
      'allContactIncluded': "সব যোগাযোগের তথ্য অন্তর্ভুক্ত",
      'joinCommunity': "আমাদের কমিউনিটিতে যোগ দিন",
      'uploadData': "ডেটা আপলোড করুন",
      'askQuestionHint': "প্রশ্ন করুন (যেমন: গত সপ্তাহের বিক্রি দেখান)",
      'queryTip': "টিপ: ডেটাবেসে প্রশ্ন করতে ফাইল খালি রাখুন",
      'responseHint': "উত্তর এখানে দেখা যাবে",
      'avgChange': "গড় পরিবর্তন",
      'revenueLeadersDesc':
          "এই বার চার্ট নির্বাচিত সময়ে আয়ের ভিত্তিতে শীর্ষ পণ্যগুলি দেখায়।",
      'salesTrendDesc':
          "এই লাইন চার্ট সাম্প্রতিক দিনের মোট বিক্রি দেখায় এবং দোকানের অগ্রগতি বুঝতে সাহায্য করে।",
      'revenueDistributionDesc':
          "এই পাই চার্ট মোট আয়ে প্রতিটি পণ্যের অংশ দেখায়।",
      'quantityDistributionDesc':
          "এই রাডার চার্ট প্রতিটি পণ্যের বিক্রি হওয়া ইউনিটের তুলনা করে।",
      'monthlySalesDesc':
          "প্রতি মাসের মোট বিক্রি দেখুন। বছরের প্রবণতা এবং সর্বোচ্চ বিক্রির সময় শনাক্ত করুন।",
      'weeklySalesDesc':
          "গত ১২ সপ্তাহের বিক্রি দেখুন। সাপ্তাহিক ধরন এবং বৃদ্ধি শনাক্ত করুন।",
      'yearlySalesDesc':
          "বিভিন্ন বছরের মোট বিক্রির তুলনা করে দীর্ঘমেয়াদি বৃদ্ধি দেখুন।",
      'howToUseTitle': "Retail Mind কীভাবে ব্যবহার করবেন",
      'step1Title': "1. বিক্রি যোগ করুন",
      'step1Desc': "বিক্রি যোগ করুন আইকন ব্যবহার করে প্রতিটি বিক্রি লিখুন।",
      'step2Title': "2. মজুত পরিচালনা করুন",
      'step2Desc': "ইনভেন্টরি স্ক্রিন থেকে পণ্যের মজুত দেখুন।",
      'step3Title': "3. রিপোর্ট দেখুন",
      'step3Desc': "বিস্তারিত বিশ্লেষণের জন্য রিপোর্ট বিভাগ খুলুন।",
      'step4Title': "4. উপহার কার্ড শেয়ার করুন",
      'step4Desc': "আপনার ডিজিটাল উপহার কার্ড গ্রাহকদের পাঠান।",
      'step5Title': "5. পেমেন্ট গ্রহণ করুন",
      'step5Desc': "সহজে পেমেন্ট নিতে আপনার QR কোড দেখান।",
      'gotIt': "বুঝেছি!",
      'dailyPerformanceRating': "দৈনিক কর্মদক্ষতার মূল্যায়ন",
      'salesIncreasedBy': "আজকের বিক্রি বেড়েছে",
      'salesDecreasedBy': "আজকের বিক্রি কমেছে",
      'bestHour': "সেরা ঘণ্টা",
      'yesterdayBestProduct': "গতকালের সেরা পণ্য:",
      'noSales': "কোনও বিক্রি নেই",
      'notAvailable': "উপলব্ধ নয়",
      'todaySales': "আজকের বিক্রি",
      'yesterdaySales': "গতকালের বিক্রি",
      'analysisAmazing':
          "দারুণ! আজ আপনি ₹{0} আয় করেছেন, যা গতকালের চেয়ে ₹{1} বেশি!",
      'analysisProgressing':
          "বিক্রি এগোচ্ছে! আজ ₹{0} বিক্রি হয়েছে। গতকালের বিক্রিকে ছাড়াতে আরও ₹{1} দরকার।",
      'analysisWaiting':
          "আজকের প্রথম বিক্রির অপেক্ষায়। দিনটিকে দারুণ করে তুলি!",
      'analysisMatch': "আজকের বিক্রি গতকালের সমান ₹{0}! ধারাবাহিক ভালো কাজ।",
      'goodMorningName': "সুপ্রভাত, {0}! ☀️",
      'goodAfternoonName': "শুভ অপরাহ্ণ, {0}! 🌤️",
      'goodEveningName': "শুভ সন্ধ্যা, {0}! 🌙",
      'tapToUploadQr': "QR আপলোড করতে ট্যাপ করুন",
      'qrUploadFormat': "গ্যালারি থেকে PNG / JPG",
      'tripleChannelActive': "তিন-চ্যানেল শনাক্তকরণ সক্রিয়",
      'listeningForPayments': "UPI, SMS এবং স্ক্রিন পর্যবেক্ষণ করা হচ্ছে...",
    },
  };

  String translate(String key) {
    return translations[locale.languageCode]?[key] ??
        translations['en']?[key] ??
        key;
  }

  String get appTitle =>
      translations[locale.languageCode]?['appTitle'] ??
      translations['en']?['appTitle'] ??
      'RETAIL MIND';
  String get tagline =>
      translations[locale.languageCode]?['tagline'] ??
      translations['en']?['tagline'] ??
      'Smart Analytics & Billing Platform';
  String get email =>
      translations[locale.languageCode]?['email'] ??
      translations['en']?['email'] ??
      'Email';
  String get password =>
      translations[locale.languageCode]?['password'] ??
      translations['en']?['password'] ??
      'Password';
  String get login =>
      translations[locale.languageCode]?['login'] ??
      translations['en']?['login'] ??
      'LOGIN';
  String get register =>
      translations[locale.languageCode]?['register'] ??
      translations['en']?['register'] ??
      'REGISTER';
  String get signIn =>
      translations[locale.languageCode]?['signIn'] ??
      translations['en']?['signIn'] ??
      'SIGN IN';
  String get createAccount =>
      translations[locale.languageCode]?['createAccount'] ??
      translations['en']?['createAccount'] ??
      'CREATE NEW ACCOUNT';
  String get signUp =>
      translations[locale.languageCode]?['signUp'] ??
      translations['en']?['signUp'] ??
      'SIGN UP';
  String get enterEmail =>
      translations[locale.languageCode]?['enterEmail'] ??
      translations['en']?['enterEmail'] ??
      'Enter your email';
  String get enterPassword =>
      translations[locale.languageCode]?['enterPassword'] ??
      translations['en']?['enterPassword'] ??
      'Enter your password';
  String get confirmPassword =>
      translations[locale.languageCode]?['confirmPassword'] ??
      translations['en']?['confirmPassword'] ??
      'Confirm password';
  String get userName =>
      translations[locale.languageCode]?['userName'] ??
      translations['en']?['userName'] ??
      'User Name';
  String get shopName =>
      translations[locale.languageCode]?['shopName'] ??
      translations['en']?['shopName'] ??
      'Shop Name';
  String get location =>
      translations[locale.languageCode]?['location'] ??
      translations['en']?['location'] ??
      'Location';
  String get invalidCredentials =>
      translations[locale.languageCode]?['invalidCredentials'] ??
      translations['en']?['invalidCredentials'] ??
      'Invalid credentials';
  String get connectionError =>
      translations[locale.languageCode]?['connectionError'] ??
      translations['en']?['connectionError'] ??
      'Connection error';
  String get welcome =>
      translations[locale.languageCode]?['welcome'] ??
      translations['en']?['welcome'] ??
      'Welcome Back';
  String get enterCredentials =>
      translations[locale.languageCode]?['enterCredentials'] ??
      translations['en']?['enterCredentials'] ??
      'Enter your credentials to continue';
  String get dashboard =>
      translations[locale.languageCode]?['dashboard'] ??
      translations['en']?['dashboard'] ??
      'Dashboard';
  String get sales =>
      translations[locale.languageCode]?['sales'] ??
      translations['en']?['sales'] ??
      'Sales';
  String get query =>
      translations[locale.languageCode]?['query'] ??
      translations['en']?['query'] ??
      'Query';
  String get giftCard =>
      translations[locale.languageCode]?['giftCard'] ??
      translations['en']?['giftCard'] ??
      'Gift Card';
  String get bills =>
      translations[locale.languageCode]?['bills'] ??
      translations['en']?['bills'] ??
      'Bills';
  String get insights =>
      translations[locale.languageCode]?['insights'] ??
      translations['en']?['insights'] ??
      'Insights';
  String get settings =>
      translations[locale.languageCode]?['settings'] ??
      translations['en']?['settings'] ??
      'Settings';
  String get logout =>
      translations[locale.languageCode]?['logout'] ??
      translations['en']?['logout'] ??
      'Logout';
  String get language =>
      translations[locale.languageCode]?['language'] ??
      translations['en']?['language'] ??
      'Language';
  String get selectLanguage =>
      translations[locale.languageCode]?['selectLanguage'] ??
      translations['en']?['selectLanguage'] ??
      'Select Language';
  String get darkMode =>
      translations[locale.languageCode]?['darkMode'] ??
      translations['en']?['darkMode'] ??
      'Dark Mode';
  String get notification =>
      translations[locale.languageCode]?['notification'] ??
      translations['en']?['notification'] ??
      'Notifications';
  String get about =>
      translations[locale.languageCode]?['about'] ??
      translations['en']?['about'] ??
      'About';
  String get share =>
      translations[locale.languageCode]?['share'] ??
      translations['en']?['share'] ??
      'Share';
  String get help =>
      translations[locale.languageCode]?['help'] ??
      translations['en']?['help'] ??
      'Help';
  String get profile =>
      translations[locale.languageCode]?['profile'] ??
      translations['en']?['profile'] ??
      'Profile';
  String get forgotPassword =>
      translations[locale.languageCode]?['forgotPassword'] ??
      translations['en']?['forgotPassword'] ??
      'Forgot Password?';

  String get welcomeBack =>
      translations[locale.languageCode]?['welcomeBack'] ??
      translations['en']?['welcomeBack'] ??
      'Welcome back,';
  String get salesByMonth =>
      translations[locale.languageCode]?['salesByMonth'] ??
      translations['en']?['salesByMonth'] ??
      'Sales by Month';
  String get salesByWeek =>
      translations[locale.languageCode]?['salesByWeek'] ??
      translations['en']?['salesByWeek'] ??
      'Sales by Week';
  String get salesByYear =>
      translations[locale.languageCode]?['salesByYear'] ??
      translations['en']?['salesByYear'] ??
      'Sales by Year';
  String get searchQuery =>
      translations[locale.languageCode]?['searchQuery'] ??
      translations['en']?['searchQuery'] ??
      'Search Query';
  String get dataUpload =>
      translations[locale.languageCode]?['dataUpload'] ??
      translations['en']?['dataUpload'] ??
      'Data Upload';
  String get addSale =>
      translations[locale.languageCode]?['addSale'] ??
      translations['en']?['addSale'] ??
      'Add Sale';
  String get totalAmount =>
      translations[locale.languageCode]?['totalAmount'] ??
      translations['en']?['totalAmount'] ??
      'TOTAL AMOUNT';
  String get recordedSuccess =>
      translations[locale.languageCode]?['recordedSuccess'] ??
      translations['en']?['recordedSuccess'] ??
      'Recorded successfully!';
  String get recordedLocally =>
      translations[locale.languageCode]?['recordedLocally'] ??
      translations['en']?['recordedLocally'] ??
      'Saved locally!';
  String get askMeAnything =>
      translations[locale.languageCode]?['askMeAnything'] ??
      translations['en']?['askMeAnything'] ??
      'Ask me anything...';
  String get aiAssistant =>
      translations[locale.languageCode]?['aiAssistant'] ??
      translations['en']?['aiAssistant'] ??
      'AI Assistant';
  String get alwaysHere =>
      translations[locale.languageCode]?['alwaysHere'] ??
      translations['en']?['alwaysHere'] ??
      'Always here to help';
  String get performanceOverview =>
      translations[locale.languageCode]?['performanceOverview'] ??
      translations['en']?['performanceOverview'] ??
      'Performance Overview';
  String get transactions =>
      translations[locale.languageCode]?['transactions'] ??
      translations['en']?['transactions'] ??
      'Transactions';
  String get avgOrder =>
      translations[locale.languageCode]?['avgOrder'] ??
      translations['en']?['avgOrder'] ??
      'Avg. Order';
  String get products =>
      translations[locale.languageCode]?['products'] ??
      translations['en']?['products'] ??
      'Products';
  String get quickActions =>
      translations[locale.languageCode]?['quickActions'] ??
      translations['en']?['quickActions'] ??
      'Quick Actions';
  String get getInsights =>
      translations[locale.languageCode]?['getInsights'] ??
      translations['en']?['getInsights'] ??
      'Get Insights';
  String get today =>
      translations[locale.languageCode]?['today'] ??
      translations['en']?['today'] ??
      'Today';
  String get week =>
      translations[locale.languageCode]?['week'] ??
      translations['en']?['week'] ??
      'Week';
  String get month =>
      translations[locale.languageCode]?['month'] ??
      translations['en']?['month'] ??
      'Month';
  String get year =>
      translations[locale.languageCode]?['year'] ??
      translations['en']?['year'] ??
      'Year';
  String get showing =>
      translations[locale.languageCode]?['showing'] ??
      translations['en']?['showing'] ??
      'Showing';
  String get phone =>
      translations[locale.languageCode]?['phone'] ??
      translations['en']?['phone'] ??
      'Phone';
  String get owner =>
      translations[locale.languageCode]?['owner'] ??
      translations['en']?['owner'] ??
      'Owner';
  String get website =>
      translations[locale.languageCode]?['website'] ??
      translations['en']?['website'] ??
      'Website';
  String get shopkeeper =>
      translations[locale.languageCode]?['shopkeeper'] ??
      translations['en']?['shopkeeper'] ??
      'SHOPKEEPER';
  String get shareCard =>
      translations[locale.languageCode]?['shareCard'] ??
      translations['en']?['shareCard'] ??
      'Share Card';
  String get viewBack =>
      translations[locale.languageCode]?['viewBack'] ??
      translations['en']?['viewBack'] ??
      'View Back';
  String get viewFront =>
      translations[locale.languageCode]?['viewFront'] ??
      translations['en']?['viewFront'] ??
      'View Front';
  String get goToDashboard =>
      translations[locale.languageCode]?['goToDashboard'] ??
      translations['en']?['goToDashboard'] ??
      'Go to Dashboard';
  String get tapToFlip =>
      translations[locale.languageCode]?['tapToFlip'] ??
      translations['en']?['tapToFlip'] ??
      'Tap to flip for QR code';
  String get tapToSeeFront =>
      translations[locale.languageCode]?['tapToSeeFront'] ??
      translations['en']?['tapToSeeFront'] ??
      'Tap to see front';
  String get scanToConnect =>
      translations[locale.languageCode]?['scanToConnect'] ??
      translations['en']?['scanToConnect'] ??
      'SCAN TO CONNECT';
  String get orScan =>
      translations[locale.languageCode]?['orScan'] ??
      translations['en']?['orScan'] ??
      'OR SCAN';
  String get allContactIncluded =>
      translations[locale.languageCode]?['allContactIncluded'] ??
      translations['en']?['allContactIncluded'] ??
      'All contact information included';
  String get personalInfo =>
      translations[locale.languageCode]?['personalInfo'] ??
      translations['en']?['personalInfo'] ??
      'Personal Info';
  String get shopDetails =>
      translations[locale.languageCode]?['shopDetails'] ??
      translations['en']?['shopDetails'] ??
      'Shop Details';
  String get security =>
      translations[locale.languageCode]?['security'] ??
      translations['en']?['security'] ??
      'Security';
  String get fullName =>
      translations[locale.languageCode]?['fullName'] ??
      translations['en']?['fullName'] ??
      'Full Name';
  String get emailAddress =>
      translations[locale.languageCode]?['emailAddress'] ??
      translations['en']?['emailAddress'] ??
      'Email Address';
  String get phoneNumber =>
      translations[locale.languageCode]?['phoneNumber'] ??
      translations['en']?['phoneNumber'] ??
      'Phone Number';
  String get shopType =>
      translations[locale.languageCode]?['shopType'] ??
      translations['en']?['shopType'] ??
      'Shop Type';
  String get taglineOptional =>
      translations[locale.languageCode]?['taglineOptional'] ??
      translations['en']?['taglineOptional'] ??
      'Tagline (optional)';
  String get websiteOptional =>
      translations[locale.languageCode]?['websiteOptional'] ??
      translations['en']?['websiteOptional'] ??
      'Website (optional)';
  String get alreadyHaveAccount =>
      translations[locale.languageCode]?['alreadyHaveAccount'] ??
      translations['en']?['alreadyHaveAccount'] ??
      'Already have an account?';
  String get joinCommunity =>
      translations[locale.languageCode]?['joinCommunity'] ??
      translations['en']?['joinCommunity'] ??
      'Join our community';
  String get uploadData =>
      translations[locale.languageCode]?['uploadData'] ??
      translations['en']?['uploadData'] ??
      'Upload Data';
  String get analytics =>
      translations[locale.languageCode]?['analytics'] ??
      translations['en']?['analytics'] ??
      'Analytics';
  String get inventory =>
      translations[locale.languageCode]?['inventory'] ??
      translations['en']?['inventory'] ??
      'Inventory';
  String get reports =>
      translations[locale.languageCode]?['reports'] ??
      translations['en']?['reports'] ??
      'Reports';
  String get last7Days =>
      translations[locale.languageCode]?['last7Days'] ??
      translations['en']?['last7Days'] ??
      'Last 7 Days';
  String get last30Days =>
      translations[locale.languageCode]?['last30Days'] ??
      translations['en']?['last30Days'] ??
      'Last 30 Days';
  String get thisYear =>
      translations[locale.languageCode]?['thisYear'] ??
      translations['en']?['thisYear'] ??
      'This Year';
  String get tapToUploadQr =>
      translations[locale.languageCode]?['tapToUploadQr'] ??
      translations['en']?['tapToUploadQr'] ??
      'Tap to upload QR';
  String get qrUploadFormat =>
      translations[locale.languageCode]?['qrUploadFormat'] ??
      translations['en']?['qrUploadFormat'] ??
      'PNG / JPG from gallery';
  String get tripleChannelActive =>
      translations[locale.languageCode]?['tripleChannelActive'] ??
      translations['en']?['tripleChannelActive'] ??
      'TRIPLE-CHANNEL DETECTION ACTIVE';
  String get listeningForPayments =>
      translations[locale.languageCode]?['listeningForPayments'] ??
      translations['en']?['listeningForPayments'] ??
      'Listening for UPI, SMS & Screen...';
  String get goodMorning =>
      translations[locale.languageCode]?['goodMorning'] ??
      translations['en']?['goodMorning'] ??
      'Good morning! â˜€ï¸';
  String get synced =>
      translations[locale.languageCode]?['synced'] ??
      translations['en']?['synced'] ??
      'SYNCED';
  String get performanceMessage =>
      translations[locale.languageCode]?['performanceMessage'] ??
      translations['en']?['performanceMessage'] ??
      'Here\'s how your shop is performing today';
  String get refresh =>
      translations[locale.languageCode]?['refresh'] ??
      translations['en']?['refresh'] ??
      'Refresh';
  String get salesTrend =>
      translations[locale.languageCode]?['salesTrend'] ??
      translations['en']?['salesTrend'] ??
      'Sales Trend';
  String get revenueDistribution =>
      translations[locale.languageCode]?['revenueDistribution'] ??
      translations['en']?['revenueDistribution'] ??
      'Revenue Distribution';
  String get quantityDistribution =>
      translations[locale.languageCode]?['quantityDistribution'] ??
      translations['en']?['quantityDistribution'] ??
      'Quantity Distribution';
  String get revenueLeaders =>
      translations[locale.languageCode]?['revenueLeaders'] ??
      translations['en']?['revenueLeaders'] ??
      'Revenue Leaders';
  String get whatChartShows =>
      translations[locale.languageCode]?['whatChartShows'] ??
      translations['en']?['whatChartShows'] ??
      'What does this chart show?';
  String get askSimpleLanguage =>
      translations[locale.languageCode]?['askSimpleLanguage'] ??
      translations['en']?['askSimpleLanguage'] ??
      'Ask in simple language';
  String get askQuestionHint =>
      translations[locale.languageCode]?['askQuestionHint'] ??
      translations['en']?['askQuestionHint'] ??
      'Ask a question (e.g. "show sales last week")';
  String get askButton =>
      translations[locale.languageCode]?['askButton'] ??
      translations['en']?['askButton'] ??
      'Ask';
  String get queryTip =>
      translations[locale.languageCode]?['queryTip'] ??
      translations['en']?['queryTip'] ??
      'Tip: Leave file empty to query your database';
  String get responseHint =>
      translations[locale.languageCode]?['responseHint'] ??
      translations['en']?['responseHint'] ??
      'Response will appear here';
  String get enterProductDetails =>
      translations[locale.languageCode]?['enterProductDetails'] ??
      translations['en']?['enterProductDetails'] ??
      'Enter product details below';
  String get addProduct =>
      translations[locale.languageCode]?['addProduct'] ??
      translations['en']?['addProduct'] ??
      'Add Product';
  String get generateBill =>
      translations[locale.languageCode]?['generateBill'] ??
      translations['en']?['generateBill'] ??
      'Generate Bill';
  String get saveSales =>
      translations[locale.languageCode]?['saveSales'] ??
      translations['en']?['saveSales'] ??
      'Save Sales';
  String get paymentMethod =>
      translations[locale.languageCode]?['paymentMethod'] ??
      translations['en']?['paymentMethod'] ??
      'Payment Method';
  String get cashOffline =>
      translations[locale.languageCode]?['cashOffline'] ??
      translations['en']?['cashOffline'] ??
      'Cash / Offline';
  String get onlineUPI =>
      translations[locale.languageCode]?['onlineUPI'] ??
      translations['en']?['onlineUPI'] ??
      'Online / UPI';
  String get confirmPayment =>
      translations[locale.languageCode]?['confirmPayment'] ??
      translations['en']?['confirmPayment'] ??
      'Confirm Payment Received';
  String get paymentConfirmed =>
      translations[locale.languageCode]?['paymentConfirmed'] ??
      translations['en']?['paymentConfirmed'] ??
      'Payment Confirmed';
  String get noSalesData =>
      translations[locale.languageCode]?['noSalesData'] ??
      translations['en']?['noSalesData'] ??
      'No sales data available';
  String get uploadInventory =>
      translations[locale.languageCode]?['uploadInventory'] ??
      translations['en']?['uploadInventory'] ??
      'Upload Inventory';
  String get selectFile =>
      translations[locale.languageCode]?['selectFile'] ??
      translations['en']?['selectFile'] ??
      'Select File';
  String get upload =>
      translations[locale.languageCode]?['upload'] ??
      translations['en']?['upload'] ??
      'Upload';
  String get analyticsOverview =>
      translations[locale.languageCode]?['analyticsOverview'] ??
      translations['en']?['analyticsOverview'] ??
      'Analytics Overview';
  String get askToScan =>
      translations[locale.languageCode]?['askToScan'] ??
      translations['en']?['askToScan'] ??
      'Ask customer to scan & pay';
  String get scannedBillTitle =>
      translations[locale.languageCode]?['scannedBillTitle'] ??
      translations['en']?['scannedBillTitle'] ??
      'Scanned Bill';
  String get askYourQuestion =>
      translations[locale.languageCode]?['askYourQuestion'] ??
      translations['en']?['askYourQuestion'] ??
      'Ask Your Question';
  String get analysisResults =>
      translations[locale.languageCode]?['analysisResults'] ??
      translations['en']?['analysisResults'] ??
      'Analysis Results';
  String get analysisSummary =>
      translations[locale.languageCode]?['analysisSummary'] ??
      translations['en']?['analysisSummary'] ??
      'Analysis Summary';
  String get detailedData =>
      translations[locale.languageCode]?['detailedData'] ??
      translations['en']?['detailedData'] ??
      'Detailed Data';
  String get total =>
      translations[locale.languageCode]?['total'] ??
      translations['en']?['total'] ??
      'Total';
  String get revenueShare =>
      translations[locale.languageCode]?['revenueShare'] ??
      translations['en']?['revenueShare'] ??
      'Revenue Share';
  String get topProductsByRevenue =>
      translations[locale.languageCode]?['topProductsByRevenue'] ??
      translations['en']?['topProductsByRevenue'] ??
      'Top Products by Revenue';
  String get volumeAnalysis =>
      translations[locale.languageCode]?['volumeAnalysis'] ??
      translations['en']?['volumeAnalysis'] ??
      'Volume Analysis';
  String get unitMovementRadar =>
      translations[locale.languageCode]?['unitMovementRadar'] ??
      translations['en']?['unitMovementRadar'] ??
      'Unit Movement Radar';
  String get upwardTrend =>
      translations[locale.languageCode]?['upwardTrend'] ??
      translations['en']?['upwardTrend'] ??
      'Upward trend';
  String get downwardTrend =>
      translations[locale.languageCode]?['downwardTrend'] ??
      translations['en']?['downwardTrend'] ??
      'Downward trend';
  String get avgChange =>
      translations[locale.languageCode]?['avgChange'] ??
      translations['en']?['avgChange'] ??
      'avg change';
  String get noProductData =>
      translations[locale.languageCode]?['noProductData'] ??
      translations['en']?['noProductData'] ??
      'No product data';
  String get volumeByProduct =>
      translations[locale.languageCode]?['volumeByProduct'] ??
      translations['en']?['volumeByProduct'] ??
      'Volume by Product';
  String get revenueLeadersDesc =>
      translations[locale.languageCode]?['revenueLeadersDesc'] ??
      translations['en']?['revenueLeadersDesc'] ??
      'This bar chart highlights the top products by revenue within the selected time frame.';
  String get salesTrendDesc =>
      translations[locale.languageCode]?['salesTrendDesc'] ??
      translations['en']?['salesTrendDesc'] ??
      "The line chart displays total sales over recent days, giving you an idea of your store's momentum.";
  String get revenueDistributionDesc =>
      translations[locale.languageCode]?['revenueDistributionDesc'] ??
      translations['en']?['revenueDistributionDesc'] ??
      'The pie (donut) chart shows how much each product contributes to overall revenue.';
  String get quantityDistributionDesc =>
      translations[locale.languageCode]?['quantityDistributionDesc'] ??
      translations['en']?['quantityDistributionDesc'] ??
      'The radar chart compares units sold per product, helping you spot high-volume items.';
  String get monthlySalesDesc =>
      translations[locale.languageCode]?['monthlySalesDesc'] ??
      translations['en']?['monthlySalesDesc'] ??
      'Track your total sales amount for each month. Identify trends and peak sales periods throughout the year.';
  String get weeklySalesDesc =>
      translations[locale.languageCode]?['weeklySalesDesc'] ??
      translations['en']?['weeklySalesDesc'] ??
      'View your sales performance over the last 12 weeks. Spot weekly patterns and week-over-week growth.';
  String get yearlySalesDesc =>
      translations[locale.languageCode]?['yearlySalesDesc'] ??
      translations['en']?['yearlySalesDesc'] ??
      'Compare total sales across different years. Perfect for tracking long-term business growth and performance trends.';

  String get howToUseTitle =>
      translations[locale.languageCode]?['howToUseTitle'] ??
      translations['en']?['howToUseTitle'] ??
      'How to Use';
  String get step1Title =>
      translations[locale.languageCode]?['step1Title'] ??
      translations['en']?['step1Title'] ??
      '';
  String get step1Desc =>
      translations[locale.languageCode]?['step1Desc'] ??
      translations['en']?['step1Desc'] ??
      '';
  String get step2Title =>
      translations[locale.languageCode]?['step2Title'] ??
      translations['en']?['step2Title'] ??
      '';
  String get step2Desc =>
      translations[locale.languageCode]?['step2Desc'] ??
      translations['en']?['step2Desc'] ??
      '';
  String get step3Title =>
      translations[locale.languageCode]?['step3Title'] ??
      translations['en']?['step3Title'] ??
      '';
  String get step3Desc =>
      translations[locale.languageCode]?['step3Desc'] ??
      translations['en']?['step3Desc'] ??
      '';
  String get step4Title =>
      translations[locale.languageCode]?['step4Title'] ??
      translations['en']?['step4Title'] ??
      '';
  String get step4Desc =>
      translations[locale.languageCode]?['step4Desc'] ??
      translations['en']?['step4Desc'] ??
      '';
  String get step5Title =>
      translations[locale.languageCode]?['step5Title'] ??
      translations['en']?['step5Title'] ??
      '';
  String get step5Desc =>
      translations[locale.languageCode]?['step5Desc'] ??
      translations['en']?['step5Desc'] ??
      '';
  String get gotIt =>
      translations[locale.languageCode]?['gotIt'] ??
      translations['en']?['gotIt'] ??
      'Got it!';

  String get dailyPerformanceRating =>
      translations[locale.languageCode]?['dailyPerformanceRating'] ??
      translations['en']?['dailyPerformanceRating'] ??
      'DAILY PERFORMANCE RATING';
  String get salesIncreasedBy =>
      translations[locale.languageCode]?['salesIncreasedBy'] ??
      translations['en']?['salesIncreasedBy'] ??
      "Today's sales increased by";
  String get salesDecreasedBy =>
      translations[locale.languageCode]?['salesDecreasedBy'] ??
      translations['en']?['salesDecreasedBy'] ??
      "Today's sales decreased by";
  String get bestHour =>
      translations[locale.languageCode]?['bestHour'] ??
      translations['en']?['bestHour'] ??
      'Best Hour';
  String get yesterdayBestProductLabel =>
      translations[locale.languageCode]?['yesterdayBestProduct'] ??
      translations['en']?['yesterdayBestProduct'] ??
      "Yesterday's best product:";
  String get noSales =>
      translations[locale.languageCode]?['noSales'] ??
      translations['en']?['noSales'] ??
      'No sales';
  String get notAvailable =>
      translations[locale.languageCode]?['notAvailable'] ??
      translations['en']?['notAvailable'] ??
      'N/A';
  String get todaySales =>
      translations[locale.languageCode]?['todaySales'] ??
      translations['en']?['todaySales'] ??
      'Today Sales';
  String get yesterdaySales =>
      translations[locale.languageCode]?['yesterdaySales'] ??
      translations['en']?['yesterdaySales'] ??
      'Yesterday Sales';
  String get analysisAmazing =>
      translations[locale.languageCode]?['analysisAmazing'] ??
      translations['en']?['analysisAmazing'] ??
      '';
  String get analysisProgressing =>
      translations[locale.languageCode]?['analysisProgressing'] ??
      translations['en']?['analysisProgressing'] ??
      '';
  String get analysisWaiting =>
      translations[locale.languageCode]?['analysisWaiting'] ??
      translations['en']?['analysisWaiting'] ??
      '';
  String get analysisMatch =>
      translations[locale.languageCode]?['analysisMatch'] ??
      translations['en']?['analysisMatch'] ??
      '';
  String get goodMorningName =>
      translations[locale.languageCode]?['goodMorningName'] ??
      translations['en']?['goodMorningName'] ??
      'Good morning, {0}! ☀️';
  String get goodAfternoonName =>
      translations[locale.languageCode]?['goodAfternoonName'] ??
      translations['en']?['goodAfternoonName'] ??
      'Good afternoon, {0}! 🌤️';
  String get goodEveningName =>
      translations[locale.languageCode]?['goodEveningName'] ??
      translations['en']?['goodEveningName'] ??
      'Good evening, {0}! 🌙';
  String get noInsights =>
      translations[locale.languageCode]?['noInsights'] ??
      translations['en']?['noInsights'] ??
      'No insights available';
  String get selectDueDate =>
      translations[locale.languageCode]?['selectDueDate'] ??
      translations['en']?['selectDueDate'] ??
      'Select Due Date';
  String get deadline =>
      translations[locale.languageCode]?['deadline'] ??
      translations['en']?['deadline'] ??
      'Deadline';
  String get overdue =>
      translations[locale.languageCode]?['overdue'] ??
      translations['en']?['overdue'] ??
      'Overdue';
  String get pendingPayment =>
      translations[locale.languageCode]?['pendingPayment'] ??
      translations['en']?['pendingPayment'] ??
      'Pending Payment';
  String get setDeadline =>
      translations[locale.languageCode]?['setDeadline'] ??
      translations['en']?['setDeadline'] ??
      'Set Deadline';
  String get attendance =>
      translations[locale.languageCode]?['attendance'] ??
      translations['en']?['attendance'] ??
      'Attendance';
  String get customers =>
      translations[locale.languageCode]?['customers'] ??
      translations['en']?['customers'] ??
      'Customers';
  String get addCustomer =>
      translations[locale.languageCode]?['addCustomer'] ??
      translations['en']?['addCustomer'] ??
      'Add Customer';
  String get customerName =>
      translations[locale.languageCode]?['customerName'] ??
      translations['en']?['customerName'] ??
      'Customer Name';
  String get invoices =>
      translations[locale.languageCode]?['invoices'] ??
      translations['en']?['invoices'] ??
      'Invoices';
  String get newInvoice =>
      translations[locale.languageCode]?['newInvoice'] ??
      translations['en']?['newInvoice'] ??
      'New Invoice';
  String get noInvoicesFound =>
      translations[locale.languageCode]?['noInvoicesFound'] ??
      translations['en']?['noInvoicesFound'] ??
      'No Invoices Found';
  String get noCustomersYet =>
      translations[locale.languageCode]?['noCustomersYet'] ??
      translations['en']?['noCustomersYet'] ??
      'No Customers Yet';
  String get noProductsYet =>
      translations[locale.languageCode]?['noProductsYet'] ??
      translations['en']?['noProductsYet'] ??
      'No Products Yet';
  String get checkIn =>
      translations[locale.languageCode]?['checkIn'] ??
      translations['en']?['checkIn'] ??
      'Check In';
  String get checkOut =>
      translations[locale.languageCode]?['checkOut'] ??
      translations['en']?['checkOut'] ??
      'Check Out';
  String get todayStatus =>
      translations[locale.languageCode]?['todayStatus'] ??
      translations['en']?['todayStatus'] ??
      "Today's Status";
  String get history =>
      translations[locale.languageCode]?['history'] ??
      translations['en']?['history'] ??
      'History';
  String get viewAll =>
      translations[locale.languageCode]?['viewAll'] ??
      translations['en']?['viewAll'] ??
      'View All';
  String get expenses =>
      translations[locale.languageCode]?['expenses'] ??
      translations['en']?['expenses'] ??
      'Expenses';
  String get workers =>
      translations[locale.languageCode]?['workers'] ??
      translations['en']?['workers'] ??
      'Workers';
  String get backup =>
      translations[locale.languageCode]?['backup'] ??
      translations['en']?['backup'] ??
      'Backup & Restore';

  // Every language offered by the voice-language picker is also a valid
  // application locale. Curated offline dictionaries currently cover the
  // ten primary locales; other supported locales use LiveTranslatedText's
  // bounded dynamic translation fallback.
  static const List<Locale> supportedLocales = [
    Locale('en'), Locale('te'), Locale('hi'), Locale('ta'),
    Locale('kn'), Locale('ml'), Locale('bn'), Locale('mr'),
    Locale('gu'), Locale('pa'), Locale('or'), Locale('as'),
    Locale('brx'), Locale('doi'), Locale('ks'), Locale('kok'),
    Locale('mai'), Locale('mni'), Locale('ne'), Locale('sa'),
    Locale('sat'), Locale('sd'), Locale('ur'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
