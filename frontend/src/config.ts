// API Configuration
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

export const config = {
  apiUrl: API_URL,
  // Google OAuth Configuration
  googleClientId: import.meta.env.VITE_GOOGLE_CLIENT_ID || '',
  // Feature toggles
  features: {
    // Set to true to enable public registration
    // Set to false to disable registration link and route access
    enableRegistration: import.meta.env.VITE_ENABLE_REGISTRATION === 'true' || false,
  },
  endpoints: {
    auth: {
      register: `${API_URL}/auth/register`,
      login: `${API_URL}/auth/login`,
      changePassword: `${API_URL}/auth/change-password`,
    },
    people: `${API_URL}/api/people`,
    types: `${API_URL}/api/types`,
    absences: `${API_URL}/api/absences`,
    smartIdentification: `${API_URL}/api/smart-identify`,
    smartIdentificationHealth: `${API_URL}/api/smart-identify/health`,
    aiInstructions: `${API_URL}/api/ai-instructions`,
    aiInstructionsReset: `${API_URL}/api/ai-instructions/reset`,
    meals: {
      analyze: `${API_URL}/meals/analyze`,
      save: `${API_URL}/meals`,
      today: `${API_URL}/meals/today`,
    },
    foods: `${API_URL}/foods`,
  },
};

export default config;
