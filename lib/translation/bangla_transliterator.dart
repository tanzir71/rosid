import 'package:rosid/core/utils/bangla_digits.dart';

/// Rule-based Bangla to Latin transliterator tuned for Bangladeshi person and
/// place name conventions (e.g. `মোঃ -> MD`, `আব্দুর -> Abdur`,
/// `রহমান -> Rahman`, `বিরুলিয়া -> Birulia`, `সাভার -> Savar`), backed by a
/// curated dictionary of 320+ common Bangladeshi name parts and districts/places.
abstract final class BanglaTransliterator {
  /// Curated dictionary of >= 300 common Bangladeshi person & place name parts
  /// with their standard English/passport spellings.
  static const Map<String, String> commonNameParts = <String, String>{
    // Honorifics & prefixes
    'মোঃ': 'MD',
    'মো.': 'MD',
    'মোহাঃ': 'MD',
    'মোহাম্মদ': 'Mohammad',
    'মুহাম্মদ': 'Muhammad',
    'মুহাম্মাদ': 'Muhammad',
    'মোসাঃ': 'Mst.',
    'মোসা.': 'Mst.',
    'মোসাম্মৎ': 'Mosammat',
    'মোসাম্মত': 'Mosammat',
    'শ্রী': 'Sri',
    'শ্রীমতী': 'Srimati',
    'বেগম': 'Begum',
    'খাতুন': 'Khatun',
    'আক্তার': 'Akter',
    'আকতার': 'Akter',
    'আখতার': 'Akhtar',
    'বানু': 'Banu',
    'বিবি': 'Bibi',
    'নাহার': 'Nahar',
    'জাহান': 'Jahan',
    'পারভীন': 'Parvin',
    'পারভিন': 'Parvin',
    'সুলতানা': 'Sultana',
    'ইয়াসমিন': 'Yasmin',
    'ইয়াসমিন': 'Yasmin',
    'ইয়াসমীন': 'Yasmin',
    'আরা': 'Ara',
    'নেছা': 'Nesa',
    'নেসা': 'Nesa',
    'ডাঃ': 'Dr.',
    'ড.': 'Dr.',
    'হাজী': 'Hazi',
    'হাজি': 'Hazi',
    'আলহাজ্ব': 'Alhaj',
    'সৈয়দ': 'Syed',
    'সৈয়দ': 'Syed',
    'সৈয়দা': 'Syeda',
    'সৈয়দা': 'Syeda',
    'শেখ': 'Sheikh',
    'মীর': 'Mir',
    'কাজী': 'Kazi',
    'কাজি': 'Kazi',
    'খন্দকার': 'Khandaker',
    'খোন্দকার': 'Khondoker',
    'মোল্লা': 'Molla',
    'মোল্যা': 'Molla',
    'মুন্সী': 'Munshi',
    'মুন্সি': 'Munshi',
    'মিয়া': 'Mia',
    'মিয়া': 'Mia',
    'মিঞা': 'Mia',
    'সরদার': 'Sardar',
    'সরকার': 'Sarker',
    'চৌধুরী': 'Chowdhury',
    'চৌধুরি': 'Chowdhury',
    'তালুকদার': 'Talukder',
    'মজুমদার': 'Majumder',
    'ভূঁইয়া': 'Bhuiyan',
    'ভূঁইয়া': 'Bhuiyan',
    'ভূইয়া': 'Bhuiyan',
    'পাটোয়ারী': 'Patwary',
    'পাটোয়ারী': 'Patwary',
    'প্রামাণিক': 'Pramanik',
    'প্রামানিক': 'Pramanik',
    'মণ্ডল': 'Mondal',
    'মন্ডল': 'Mondal',
    'বিশ্বাস': 'Biswas',
    'হাওলাদার': 'Howlader',
    'শিকদার': 'Sikder',
    'সিকদার': 'Sikder',
    'দেওয়ান': 'Dewan',
    'দেওয়ান': 'Dewan',
    'ফকির': 'Fakir',
    'ব্যাপারী': 'Bepari',
    'বেপারী': 'Bepari',
    'খান': 'Khan',
    'খাঁন': 'Khan',
    'খাঁ': 'Khan',
    'আহমেদ': 'Ahmed',
    'আহমদ': 'Ahmad',
    'আহম্মদ': 'Ahammad',
    'আহম্মেদ': 'Ahammed',
    'হোসেন': 'Hossain',
    'হোসাইন': 'Hossain',
    'হুসেন': 'Hussain',
    'ইসলাম': 'Islam',
    'রহমান': 'Rahman',
    'রহিম': 'Rahim',
    'করিম': 'Karim',
    'করীম': 'Karim',
    'উদ্দিন': 'Uddin',
    'উদ্দীন': 'Uddin',
    'আলম': 'Alam',
    'আলী': 'Ali',
    'আলি': 'Ali',
    'হাসান': 'Hasan',
    'হক': 'Haque',
    'উল্লাহ': 'Ullah',
    'উল্যাহ': 'Ullah',
    'আব্দুল': 'Abdul',
    'আবদুল': 'Abdul',
    'আব্দুর': 'Abdur',
    'আবদুর': 'Abdur',
    'আব্দুস': 'Abdus',
    'আবদুস': 'Abdus',
    'আব্দুল্লাহ': 'Abdullah',
    'আবদুল্লাহ': 'Abdullah',
    'আবু': 'Abu',
    'আবুল': 'Abul',
    'নূর': 'Nur',
    'নুর': 'Nur',
    'নূরুল': 'Nurul',
    'নুরুল': 'Nurul',
    'শামসুল': 'Shamsul',
    'শামসুর': 'Shamsur',
    'জহিরুল': 'Zahirul',
    'জহির': 'Zahir',
    'নজরুল': 'Nazrul',
    'সিরাজুল': 'Sirajul',
    'সিরাজ': 'Siraj',
    'রফিকুল': 'Rafiqul',
    'রফিক': 'Rafiq',
    'শফিকুল': 'Shafiqul',
    'শফিক': 'Shafiq',
    'আমিনুল': 'Aminul',
    'আমিন': 'Amin',
    'সাইফুল': 'Saiful',
    'তারিকুল': 'Tariqul',
    'তারেক': 'Tarek',
    'কামরুল': 'Kamrul',
    'কামাল': 'Kamal',
    'জামাল': 'Jamal',
    'বেলাল': 'Belal',
    'হেলাল': 'Helal',
    'জালাল': 'Jalal',
    'দেলোয়ার': 'Delwar',
    'দেলোয়ার': 'Delwar',
    'আনোয়ার': 'Anwar',
    'আনোয়ার': 'Anwar',
    'আক্তারুজ্জামান': 'Akteruzzaman',
    'আসাদুজ্জামান': 'Asaduzzaman',
    'কামরুজ্জামান': 'Kamruzzaman',
    'বদিউজ্জামান': 'Badiuzzaman',
    'মনিরুজ্জামান': 'Moniruzzaman',
    'নুরুজ্জামান': 'Nuruzzaman',
    'শহিদুজ্জামান': 'Shahiduzzaman',
    'জামান': 'Zaman',
    'মাহমুদ': 'Mahmud',
    'মাহমুদুল': 'Mahmudul',
    'মাসুদ': 'Masud',
    'মাসুম': 'Masum',
    'মামুন': 'Mamun',
    'মোস্তফা': 'Mostafa',
    'মস্তফা': 'Mostafa',
    'মজিবুর': 'Mojibur',
    'মুজিবুর': 'Mujibur',
    'হাবিবুর': 'Habibur',
    'হাবিব': 'Habib',
    'লুৎফর': 'Lutfur',
    'লুৎফুর': 'Lutfur',
    'মকবুল': 'Mokbul',
    'মফিজুর': 'Mofizur',
    'মফিজুল': 'Mofizul',
    'মাহবুবুর': 'Mahbubur',
    'মাহবুব': 'Mahbub',
    'মিজানুর': 'Mizanur',
    'মিজান': 'Mizan',
    'মোশাররফ': 'Mosharraf',
    'মোশারফ': 'Mosharaf',
    'মাহফুজুর': 'Mahfuzur',
    'মাহফুজ': 'Mahfuz',
    'মোতাহার': 'Motahar',
    'মোতালিব': 'Motalib',
    'মোতালেব': 'Motaleb',
    'মাহাবুব': 'Mahabub',
    'মোখলেছুর': 'Mokhlesur',
    'মুখলেসুর': 'Mukhlesur',
    'জিয়াউর': 'Ziaur',
    'জিয়াউর': 'Ziaur',
    'আতাউর': 'Ataur',
    'আজিজুর': 'Azizur',
    'আজিজুল': 'Azizul',
    'আজিজ': 'Aziz',
    'বজলুর': 'Bazlur',
    'ফজলুর': 'Fazlur',
    'ফজলুল': 'Fazlul',
    'মজিবর': 'Mojibor',
    'মতিন': 'Matin',
    'মান্নান': 'Mannan',
    'মালেক': 'Malek',
    'খালেক': 'Khalek',
    'সাত্তার': 'Sattar',
    'জব্বার': 'Jabbar',
    'গফুর': 'Gafur',
    'কাদের': 'Kader',
    'কুদ্দুস': 'Kuddus',
    'হাকিম': 'Hakim',
    'হালিম': 'Halim',
    'হামিদ': 'Hamid',
    'লতিফ': 'Latif',
    'রশিদ': 'Rashid',
    'রশীদ': 'Rashid',
    'সালাম': 'Salam',
    'সামাদ': 'Samad',
    'সোবহান': 'Sobhan',
    'সুবহান': 'Subhan',
    'মজিদ': 'Majid',
    'ওয়াহিদ': 'Wahid',
    'ওয়াহিদ': 'Wahid',
    'ওহাব': 'Ohab',
    'বশির': 'Bashir',
    'নাসির': 'Nasir',
    'নাসিরুদ্দিন': 'Nasiruddin',
    'জসিম': 'Jashim',
    'শহীদ': 'Shahid',
    'শহিদ': 'Shahid',
    'শহিদুল': 'Shahidul',
    'জাহিদুল': 'Jahidul',
    'জাহিদ': 'Jahid',
    'রিয়াদ': 'Riad',
    'রিয়াদ': 'Riad',
    'তানভীর': 'Tanvir',
    'তানভির': 'Tanvir',
    'তানজির': 'Tanzir',
    'তানজীর': 'Tanzir',
    'সাকিব': 'Sakib',
    'রাকিব': 'Rakib',
    'রাকিবুল': 'Rakibul',
    'আরিফুল': 'Ariful',
    'আরিফ': 'Arif',
    'আশরাফুল': 'Ashraful',
    'আশরাফ': 'Ashraf',
    'ইমরান': 'Imran',
    'ফারুক': 'Faruk',
    'সোহেল': 'Sohel',
    'রুবেল': 'Rubel',
    'রাসেল': 'Rasel',
    'সবুজ': 'Sabuj',
    'সুমন': 'Sumon',
    'রিপন': 'Ripon',
    'লিটন': 'Liton',
    'বাবু': 'Babu',
    'বাবুল': 'Babul',
    'খোকন': 'Khokon',
    'রতন': 'Ratan',
    'স্বপন': 'Swapan',
    'তপন': 'Tapan',
    'বিপ্লব': 'Biplob',
    'সঞ্জয়': 'Sanjoy',
    'সঞ্জয়': 'Sanjoy',
    'প্রদীপ': 'Pradip',
    'সুনীল': 'Sunil',
    'অনিল': 'Anil',
    'অমল': 'Amal',
    'কমল': 'Kamal',
    'বিমল': 'Bimal',
    'নির্মল': 'Nirmal',
    'দাস': 'Das',
    'দত্ত': 'Dutta',
    'সেন': 'Sen',
    'রায়': 'Roy',
    'রায়': 'Roy',
    'সাহা': 'Saha',
    'পাল': 'Pal',
    'বসু': 'Basu',
    'ঘোষ': 'Ghosh',
    'দেব': 'Deb',
    'দেবনাথ': 'Debnath',
    'চক্রবর্তী': 'Chakraborty',
    'ভট্টাচার্য': 'Bhattacharya',
    'মুখার্জী': 'Mukherjee',
    'ব্যানার্জী': 'Banerjee',
    'শর্মা': 'Sharma',
    'বর্মন': 'Barman',
    'বড়ুয়া': 'Barua',
    'বড়ুয়া': 'Barua',
    'চাকমা': 'Chakma',
    'মারমা': 'Marma',
    'ত্রিপুরা': 'Tripura',
    'কুমার': 'Kumar',
    'চন্দ্র': 'Chandra',
    'রানী': 'Rani',
    'রানি': 'Rani',
    'দেবী': 'Devi',
    'বালা': 'Bala',
    // Common Bangladeshi female names
    'ফারহানা': 'Farhana',
    'রোকেয়া': 'Rokeya',
    'রোকেয়া': 'Rokeya',
    'ফাতেমা': 'Fatema',
    'আয়েশা': 'Ayesha',
    'আয়েশা': 'Ayesha',
    'খাদিজা': 'Khadija',
    'মরিয়ম': 'Mariam',
    'মরিয়ম': 'Mariam',
    'জান্নাতুল': 'Jannatul',
    'জান্নাত': 'Jannat',
    'ফেরদৌস': 'Ferdous',
    'ফেরদৌসী': 'Ferdousi',
    'নুসরাত': 'Nusrat',
    'সাদিয়া': 'Sadia',
    'সাদিয়া': 'Sadia',
    'নাদিয়া': 'Nadia',
    'নাদিয়া': 'Nadia',
    'তাসনিম': 'Tasnim',
    'তাসনিয়া': 'Tasnia',
    'তাসনিয়া': 'Tasnia',
    'সুমাইয়া': 'Sumaiya',
    'সুমাইয়া': 'Sumaiya',
    'মারিয়া': 'Maria',
    'মারিয়া': 'Maria',
    'শারমিন': 'Sharmin',
    'শিরিন': 'Shirin',
    'সালমা': 'Salma',
    'নাজমা': 'Nazma',
    'রহিমা': 'Rahima',
    'করিমা': 'Karima',
    'হালিমা': 'Halima',
    'আমেনা': 'Amena',
    'রাবেয়া': 'Rabeya',
    'রাবেয়া': 'Rabeya',
    'জাহানারা': 'Jahanara',
    'দিলারা': 'Dilara',
    'শাহানাজ': 'Shahanaz',
    'শাহনাজ': 'Shahnaz',
    'রুমা': 'Ruma',
    'ঝুমা': 'Jhuma',
    'সীমা': 'Sima',
    'রীনা': 'Rina',
    'মীনা': 'Mina',
    'নাসরিন': 'Nasrin',
    'নাসরীন': 'Nasrin',
    'তাহমিনা': 'Tahmina',
    'হোসনে': 'Hosne',
    'হুসনে': 'Husne',
    'লুবনা': 'Lubna',
    'সাবিনা': 'Sabina',
    'সাবরিনা': 'Sabrina',
    'মাহমুদা': 'Mahmuda',
    'মাসুদা': 'Masuda',
    'কামরুন্নাহার': 'Kamrunnahar',
    'শামসুন্নাহার': 'Shamsunnahar',
    'নূরুন্নাহার': 'Nurunnahar',
    'বদরুন্নাহার': 'Badrunnahar',
    'রওশন': 'Rowshan',
    'মনোয়ারা': 'Monowara',
    'মনোয়ারা': 'Monowara',
    'আনোয়ারা': 'Anowara',
    'আনোয়ারা': 'Anowara',
    'রেহানা': 'Rehana',
    'সেলিনা': 'Selina',
    'বিলকিস': 'Bilkis',
    'হাছিনা': 'Hasina',
    'হাসিনা': 'Hasina',
    'নাজমুন': 'Nazmun',
    'মেহেরুন': 'Meherun',
    // Districts, cities, upazilas & common mouzas/places in Bangladesh
    'ঢাকা': 'Dhaka',
    'চট্টগ্রাম': 'Chattogram',
    'রাজশাহী': 'Rajshahi',
    'খুলনা': 'Khulna',
    'বরিশাল': 'Barishal',
    'সিলেট': 'Sylhet',
    'রংপুর': 'Rangpur',
    'ময়মনসিংহ': 'Mymensingh',
    'ময়মনসিংহ': 'Mymensingh',
    'গাজীপুর': 'Gazipur',
    'নারায়ণগঞ্জ': 'Narayanganj',
    'নারায়ণগঞ্জ': 'Narayanganj',
    'কুমিল্লা': 'Cumilla',
    'নোয়াখালী': 'Noakhali',
    'নোয়াখালী': 'Noakhali',
    'ফেনী': 'Feni',
    'ব্রাহ্মণবাড়িয়া': 'Brahmanbaria',
    'ব্রাহ্মণবাড়িয়া': 'Brahmanbaria',
    'চাঁদপুর': 'Chandpur',
    'লক্ষ্মীপুর': 'Lakshmipur',
    'কক্সবাজার': "Cox's Bazar",
    'রাঙ্গামাটি': 'Rangamati',
    'বান্দরবান': 'Bandarban',
    'খাগড়াছড়ি': 'Khagrachhari',
    'বগুড়া': 'Bogura',
    'বগুড়া': 'Bogura',
    'পাবনা': 'Pabna',
    'সিরাজগঞ্জ': 'Sirajganj',
    'নাটোর': 'Natore',
    'নওগাঁ': 'Naogaon',
    'চাঁপাইনবাবগঞ্জ': 'Chapainawabganj',
    'জয়পুরহাট': 'Joypurhat',
    'যশোর': 'Jashore',
    'সাতক্ষীরা': 'Satkhira',
    'বাগেরহাট': 'Bagerhat',
    'কুষ্টিয়া': 'Kushtia',
    'কুষ্টিয়া': 'Kushtia',
    'ঝিনাইদহ': 'Jhenaidah',
    'চুয়াডাঙ্গা': 'Chuadanga',
    'মেহেরপুর': 'Meherpur',
    'মাগুরা': 'Magura',
    'নড়াইল': 'Narail',
    'ফরিদপুর': 'Faridpur',
    'মাদারীপুর': 'Madaripur',
    'শরীয়তপুর': 'Shariatpur',
    'গোপালগঞ্জ': 'Gopalganj',
    'রাজবাড়ী': 'Rajbari',
    'মুন্সীগঞ্জ': 'Munshiganj',
    'মানিকগঞ্জ': 'Manikganj',
    'নরসিংদী': 'Narsingdi',
    'টাঙ্গাইল': 'Tangail',
    'কিশোরগঞ্জ': 'Kishoreganj',
    'জামালপুর': 'Jamalpur',
    'শেরপুর': 'Sherpur',
    'নেত্রকোণা': 'Netrokona',
    'নেত্রকোনা': 'Netrokona',
    'সুনামগঞ্জ': 'Sunamganj',
    'হবিগঞ্জ': 'Habiganj',
    'মৌলভীবাজার': 'Moulvibazar',
    'দিনাজপুর': 'Dinajpur',
    'ঠাকুরগাঁও': 'Thakurgaon',
    'পঞ্চগড়': 'Panchagarh',
    'নীলফামারী': 'Nilphamari',
    'লালমনিরহাট': 'Lalmonirhat',
    'কুড়িগ্রাম': 'Kurigram',
    'গাইবান্ধা': 'Gaibandha',
    'পটুয়াখালী': 'Patuakhali',
    'ভোলা': 'Bhola',
    'পিরোজপুর': 'Pirojpur',
    'ঝালকাঠি': 'Jhalokati',
    'বরগুনা': 'Barguna',
    'সাভার': 'Savar',
    'বিরুলিয়া': 'Birulia',
    'বিরুলিয়া': 'Birulia',
    'আশুলিয়া': 'Ashulia',
    'আশুলিয়া': 'Ashulia',
    'ধামরাই': 'Dhamrai',
    'কেরানীগঞ্জ': 'Keraniganj',
    'দোহার': 'Dohar',
    'নবাবগঞ্জ': 'Nawabganj',
    'টঙ্গী': 'Tongi',
    'কালিয়াকৈর': 'Kaliakair',
    'শ্রীপুর': 'Sreepur',
    'কাপাসিয়া': 'Kapasia',
    'মিরপুর': 'Mirpur',
    'ধানমন্ডি': 'Dhanmondi',
    'গুলশান': 'Gulshan',
    'বনানী': 'Banani',
    'উত্তরা': 'Uttara',
    'মোহাম্মদপুর': 'Mohammadpur',
    'মতিঝিল': 'Motijheel',
    'তেজগাঁও': 'Tejgaon',
    'রমনা': 'Ramna',
    'যাত্রাবাড়ী': 'Jatrabari',
    'লালবাগ': 'Lalbagh',
    'কোতোয়ালী': 'Kotwali',
    'সদর': 'Sadar',
    'রূপগঞ্জ': 'Rupganj',
    'সোনারগাঁও': 'Sonargaon',
    'বন্দর': 'Bandar',
    'সিদ্ধিরগঞ্জ': 'Siddhirganj',
    'ফতুল্লা': 'Fatullah',
    'বাংলাদেশ': 'Bangladesh',
  };

  static const Map<String, String> _independentVowels = <String, String>{
    'অ': 'a',
    'আ': 'a',
    'ই': 'i',
    'ঈ': 'i',
    'উ': 'u',
    'ঊ': 'u',
    'ঋ': 'ri',
    'এ': 'e',
    'ঐ': 'oi',
    'ও': 'o',
    'ঔ': 'ou',
  };

  static const Map<String, String> _vowelSigns = <String, String>{
    'া': 'a',
    'ি': 'i',
    'ী': 'i',
    'ু': 'u',
    'ূ': 'u',
    'ৃ': 'ri',
    'ে': 'e',
    'ৈ': 'oi',
    'ো': 'o',
    'ৌ': 'ou',
  };

  static const Map<String, String> _consonants = <String, String>{
    'ক': 'k',
    'খ': 'kh',
    'গ': 'g',
    'ঘ': 'gh',
    'ঙ': 'ng',
    'চ': 'ch',
    'ছ': 'chh',
    'জ': 'j',
    'ঝ': 'jh',
    'ঞ': 'n',
    'ট': 't',
    'ঠ': 'th',
    'ড': 'd',
    'ঢ': 'dh',
    'ণ': 'n',
    'ত': 't',
    'থ': 'th',
    'দ': 'd',
    'ধ': 'dh',
    'ন': 'n',
    'প': 'p',
    'ফ': 'f',
    'ব': 'b',
    'ভ': 'bh',
    'ম': 'm',
    'য': 'j',
    'র': 'r',
    'ল': 'l',
    'শ': 'sh',
    'ষ': 'sh',
    'স': 's',
    'হ': 'h',
    'ড়': 'r',
    'ড়': 'r',
    'ঢ়': 'rh',
    'ঢ়': 'rh',
    'য়': 'y',
    'য়': 'y',
    'ৎ': 't',
    'ং': 'ng',
    'ঃ': 'h',
    'ঁ': '',
  };

  /// Transliterates a Bangla name or phrase word-by-word using
  /// [commonNameParts] first, falling back to phonetic rules with Title Case.
  static String transliterate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final tokens = trimmed.split(RegExp(r'\s+'));
    final out = <String>[];

    for (final token in tokens) {
      final cleaned = token.replaceAll(RegExp(r'^[,;:\(\)]+|[,;:\(\)]+$'), '');
      if (cleaned.isEmpty) continue;

      final dictHit = commonNameParts[cleaned];
      if (dictHit != null) {
        out.add(dictHit);
        continue;
      }

      // Already Latin/digits? Normalize Bangla digits and preserve.
      if (!RegExp(r'[\u0980-\u09FF]').hasMatch(cleaned)) {
        out.add(toLatinDigits(cleaned));
        continue;
      }

      // Handle compound words joined with hyphen.
      if (cleaned.contains('-')) {
        out.add(cleaned.split('-').map(_transliterateWord).join('-'));
      } else {
        out.add(_transliterateWord(cleaned));
      }
    }

    return out.join(' ');
  }

  static String _transliterateWord(String word) {
    final dictHit = commonNameParts[word];
    if (dictHit != null) return dictHit;

    // Normalize decomposed nukta characters (ড়, ঢ়, য়) first.
    final normalized = word
        .replaceAll('ড\u09BC', 'ড়')
        .replaceAll('ঢ\u09BC', 'ঢ়')
        .replaceAll('য\u09BC', 'য়');

    final chars = normalized.runes.map(String.fromCharCode).toList();
    final sb = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      final next = i + 1 < chars.length ? chars[i + 1] : null;
      final next2 = i + 2 < chars.length ? chars[i + 2] : null;

      if (_independentVowels.containsKey(ch)) {
        sb.write(_independentVowels[ch]);
        continue;
      }
      if (_vowelSigns.containsKey(ch)) {
        sb.write(_vowelSigns[ch]);
        continue;
      }
      if (ch == '্') {
        // Virama / hasanta suppresses inherent vowel.
        continue;
      }

      final cons = _consonants[ch];
      if (cons != null) {
        // Handle য-ফলা (্ + য) after consonant: e.g. শ্যাম -> shyam, বিদ্যা -> bidya
        if (next == '্' && next2 == 'য') {
          sb.write(cons);
          sb.write('y');
          i += 2;
          // If followed by vowel sign, loop will emit it; otherwise emit 'a' if internal.
          final after = i + 1 < chars.length ? chars[i + 1] : null;
          if (after != null &&
              !_vowelSigns.containsKey(after) &&
              after != '্') {
            sb.write('a');
          }
          continue;
        }
        sb.write(cons);
        // Add inherent 'a' if this is a consonant followed by another consonant
        // (not virama, not vowel sign, not final character, not ং/ঃ/ৎ/ঁ).
        const nonSyllabic = {'ৎ', 'ং', 'ঃ', 'ঁ'};
        if (!nonSyllabic.contains(ch) &&
            next != null &&
            next != '্' &&
            !_vowelSigns.containsKey(next) &&
            !_independentVowels.containsKey(next) &&
            next != 'ঁ') {
          sb.write('a');
        }
        continue;
      }

      // Digits or punctuation
      sb.write(toLatinDigits(ch));
    }

    final raw = sb.toString();
    if (raw.isEmpty) return '';
    return raw[0].toUpperCase() + raw.substring(1);
  }
}
