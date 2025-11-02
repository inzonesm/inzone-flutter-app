// API Configuration
// Switch between local and production backends

class ApiConfig {
  // Set this to true for local testing, false for production
  static const bool useLocalBackend = true; // 🔧 Changed to true for local testing
  
  static const String localBackendUrl = 'http://10.0.2.2:5000'; // For Android emulator
  // static const String localBackendUrl = 'http://localhost:5000'; // For iOS simulator
  
  static const String productionBackendUrl = 
      'https://inzoneapi-912424781531.us-central1.run.app';
  
  // Get the current backend URL based on configuration
  static String get baseUrl => useLocalBackend ? localBackendUrl : productionBackendUrl;
  
  // Helper method to get full endpoint URL
  static String endpoint(String path) {
    return '$baseUrl$path';
  }
}
