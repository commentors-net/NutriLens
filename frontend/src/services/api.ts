import axios from "axios";
import type { AxiosInstance } from "axios";
import config from "@/config";

// Create axios instance with default config
const apiClient: AxiosInstance = axios.create({
  baseURL: config.apiUrl,
  headers: {
    "Content-Type": "application/json",
  },
});

// Request interceptor to add JWT token to all requests
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("access_token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor to handle 401 errors (token expired)
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid, clear storage and redirect to login
      localStorage.removeItem("access_token");
      localStorage.removeItem("username");
      localStorage.removeItem("allowed_systems");
      localStorage.removeItem("selected_system");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

// ============================================
// Authentication API
// ============================================

export interface RegisterRequest {
  username: string;
  password: string;
}

export interface RegisterResponse {
  qr: string;
  secret: string;
  username: string;
  id: number;
}

export interface LoginRequest {
  username: string;
  password: string;
  token: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
  username: string;
  allowed_systems: string[];
  default_system: string;
}

export interface GoogleLoginRequest {
  id_token: string;
}

export interface UserSystemsResponse {
  username: string;
  allowed_systems: string[];
  default_system: string;
}

export interface UserAccessItem {
  user_id: string;
  username: string;
  allowed_systems: string[];
}

export interface UserAccessUpdate {
  allowed_systems: string[];
}

export interface UserAdminUpdate {
  is_admin: boolean;
}

export interface UserDetailResponse {
  user_id: string;
  username: string;
  allowed_systems: string[];
  is_admin: boolean;
}

type AuthSystem = "" | "leave-tracker" | "nutrilens";

const authBasePath = (system: AuthSystem): string => {
  if (system === "nutrilens") {
    return "/nutrilens/auth";
  }
  if (system === "leave-tracker") {
    return "/leave-tracker/auth";
  }
  return "/auth";
};

export const authApi = {
  register: async (
    data: RegisterRequest,
    system: AuthSystem = "",
  ): Promise<RegisterResponse> => {
    const response = await axios.post(`${config.apiUrl}${authBasePath(system)}/register`, data);
    return response.data;
  },

  login: async (data: LoginRequest, system: AuthSystem = ""): Promise<LoginResponse> => {
    const response = await axios.post(`${config.apiUrl}${authBasePath(system)}/login`, data);
    return response.data;
  },

  googleLogin: async (
    data: GoogleLoginRequest,
    system: AuthSystem = "",
  ): Promise<LoginResponse> => {
    const response = await axios.post(`${config.apiUrl}${authBasePath(system)}/google-login`, data);
    return response.data;
  },

  me: async (system: AuthSystem = ""): Promise<UserSystemsResponse> => {
    const response = await apiClient.get(`${authBasePath(system)}/me`);
    return response.data;
  },

  listUserAccess: async (system: AuthSystem = ""): Promise<UserAccessItem[]> => {
    const response = await apiClient.get(`${authBasePath(system)}/user-access`);
    return response.data;
  },

  updateUserAccess: async (
    username: string,
    data: UserAccessUpdate,
    system: AuthSystem = "",
  ): Promise<UserAccessItem> => {
    const response = await apiClient.put(`${authBasePath(system)}/user-access/${encodeURIComponent(username)}`, data);
    return response.data;
  },

  changePassword: async (data: {
    username: string;
    old_password: string;
    new_password: string;
  }, system: AuthSystem = ""): Promise<{ message: string }> => {
    const response = await apiClient.post(`${authBasePath(system)}/change-password`, data);
    return response.data;
  },

  getUserDetail: async (username: string, system: AuthSystem = ""): Promise<UserDetailResponse> => {
    const response = await apiClient.get(`${authBasePath(system)}/user/${encodeURIComponent(username)}`);
    return response.data;
  },

  updateUserAdminStatus: async (
    username: string,
    data: UserAdminUpdate,
    system: AuthSystem = "",
  ): Promise<UserDetailResponse> => {
    const response = await apiClient.put(
      `${authBasePath(system)}/user/${encodeURIComponent(username)}/admin`,
      data
    );
    return response.data;
  },
};

// ============================================
// People API
// ============================================

export interface Person {
  id: number;
  name: string;
}

export interface PersonCreate {
  name: string;
}

export const peopleApi = {
  getAll: async (): Promise<Person[]> => {
    const response = await apiClient.get(config.endpoints.people);
    return response.data;
  },

  create: async (data: PersonCreate): Promise<Person> => {
    const response = await apiClient.post(config.endpoints.people, data);
    return response.data;
  },

  update: async (id: number, data: PersonCreate): Promise<Person> => {
    const response = await apiClient.put(`${config.endpoints.people}/${id}`, data);
    return response.data;
  },

  delete: async (id: number): Promise<{ message: string }> => {
    const response = await apiClient.delete(`${config.endpoints.people}/${id}`);
    return response.data;
  },
};

// ============================================
// Leave Types API
// ============================================

export interface LeaveType {
  id: number;
  name: string;
}

export interface LeaveTypeCreate {
  name: string;
}

export const typesApi = {
  getAll: async (): Promise<LeaveType[]> => {
    const response = await apiClient.get(config.endpoints.types);
    return response.data;
  },

  create: async (data: LeaveTypeCreate): Promise<LeaveType> => {
    const response = await apiClient.post(config.endpoints.types, data);
    return response.data;
  },

  update: async (id: number, data: LeaveTypeCreate): Promise<LeaveType> => {
    const response = await apiClient.put(`${config.endpoints.types}/${id}`, data);
    return response.data;
  },

  delete: async (id: number): Promise<{ message: string }> => {
    const response = await apiClient.delete(`${config.endpoints.types}/${id}`);
    return response.data;
  },
};

// ============================================
// Absences API
// ============================================

export interface Absence {
  id: number;
  person_id: number;
  date: string;
  duration: string;
  type_id: number;
  reason: string;
  applied: number;
}

export interface AbsenceCreate {
  person_id: number;
  date: string;
  duration: string;
  type_id: number;
  reason: string;
  applied?: number;
}

export interface AbsenceUpdate {
  applied: number;
}

export interface AbsencesFilterParams {
  person_id?: number;
  type_id?: number;
  date_from?: string;
  date_to?: string;
  skip?: number;
  limit?: number;
}

export const absencesApi = {
  getAll: async (params?: AbsencesFilterParams): Promise<Absence[]> => {
    const queryParams = new URLSearchParams();
    if (params?.person_id) queryParams.append('person_id', params.person_id.toString());
    if (params?.type_id) queryParams.append('type_id', params.type_id.toString());
    if (params?.date_from) queryParams.append('date_from', params.date_from);
    if (params?.date_to) queryParams.append('date_to', params.date_to);
    if (params?.skip) queryParams.append('skip', params.skip.toString());
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    
    const url = queryParams.toString() 
      ? `${config.endpoints.absences}?${queryParams.toString()}`
      : config.endpoints.absences;
    
    const response = await apiClient.get(url);
    return response.data;
  },

  create: async (data: AbsenceCreate): Promise<Absence> => {
    const response = await apiClient.post(config.endpoints.absences, data);
    return response.data;
  },

  update: async (id: number, data: AbsenceUpdate): Promise<Absence> => {
    const response = await apiClient.patch(`${config.endpoints.absences}/${id}`, data);
    return response.data;
  },

  delete: async (id: number): Promise<{ message: string }> => {
    const response = await apiClient.delete(`${config.endpoints.absences}/${id}`);
    return response.data;
  },

  bulkDelete: async (ids: number[]): Promise<{ message: string }> => {
    const response = await apiClient.post(`${config.endpoints.absences}/bulk-delete`, ids);
    return response.data;
  },

  bulkUpdateApplied: async (ids: number[], applied: number): Promise<{ message: string }> => {
    const response = await apiClient.post(`${config.endpoints.absences}/bulk-update-applied`, {
      ids,
      applied
    });
    return response.data;
  },
};

// ============================================
// Smart Identification API
// ============================================

export interface ParsedLeaveEntry {
  person_name: string;
  date: string;
  leave_type: string;
  reason: string;
  confidence: string;
}

export interface SmartIdentificationRequest {
  conversation: string;
}

export interface SmartIdentificationResponse {
  entries: ParsedLeaveEntry[];
  raw_analysis: string;
}

export interface SmartIdentificationHealth {
  status: string;
  message: string;
  configured: boolean;
  model?: string;
}

export const smartIdentificationApi = {
  analyze: async (data: SmartIdentificationRequest): Promise<SmartIdentificationResponse> => {
    const response = await apiClient.post(config.endpoints.smartIdentification, data);
    return response.data;
  },

  checkHealth: async (): Promise<SmartIdentificationHealth> => {
    const response = await apiClient.get(config.endpoints.smartIdentificationHealth);
    return response.data;
  },
};

// ============================================
// Meals API
// ============================================

export interface Macros {
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface MealItem {
  food_id: string;
  label: string;
  grams: number;
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
}

export interface Meal {
  meal_id: string;
  timestamp: string;
  items: MealItem[];
  total_kcal: number;
  notes?: string;
}

export interface MealTotalResponse {
  total_kcal: number;
  total_protein_g: number;
  total_carbs_g: number;
  total_fat_g: number;
  meal_count: number;
  meals: Meal[];
}

export const mealsApi = {
  getTodayTotals: async (): Promise<MealTotalResponse> => {
    const response = await apiClient.get(config.endpoints.meals.today);
    return response.data;
  },

  getMealsByDate: async (dateStr: string): Promise<MealTotalResponse> => {
    const response = await apiClient.get(`${config.endpoints.meals.today}?date=${dateStr}`);
    return response.data;
  },
};

// ============================================
// Foods API
// ============================================

export interface Food {
  food_id: string;
  name: string;
  kcal_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
}

export interface FoodCreate {
  name: string;
  kcal_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
}

export interface FoodUpdate {
  name?: string;
  kcal_per_100g?: number;
  protein_per_100g?: number;
  carbs_per_100g?: number;
  fat_per_100g?: number;
}

export const foodsApi = {
  listAll: async (): Promise<Food[]> => {
    const response = await apiClient.get(config.endpoints.foods);
    return response.data;
  },

  getById: async (foodId: string): Promise<Food> => {
    const response = await apiClient.get(`${config.endpoints.foods}/${foodId}`);
    return response.data;
  },

  create: async (data: FoodCreate): Promise<Food> => {
    const response = await apiClient.post(config.endpoints.foods, data);
    return response.data;
  },

  update: async (foodId: string, data: FoodUpdate): Promise<Food> => {
    const response = await apiClient.put(`${config.endpoints.foods}/${foodId}`, data);
    return response.data;
  },

  delete: async (foodId: string): Promise<{ status: string; food_id: string }> => {
    const response = await apiClient.delete(`${config.endpoints.foods}/${foodId}`);
    return response.data;
  },
};

// ============================================
// AI Instructions API
// ============================================

export interface AIInstructions {
  id: number;
  instructions: string;
  created_at: string;
  updated_at: string;
}

export interface AIInstructionsUpdate {
  instructions: string;
}

export const aiInstructionsApi = {
  get: async (): Promise<AIInstructions> => {
    const response = await apiClient.get(config.endpoints.aiInstructions);
    return response.data;
  },

  update: async (data: AIInstructionsUpdate): Promise<AIInstructions> => {
    const response = await apiClient.put(config.endpoints.aiInstructions, data);
    return response.data;
  },

  reset: async (): Promise<AIInstructions> => {
    const response = await apiClient.post(config.endpoints.aiInstructionsReset);
    return response.data;
  },
};

// Export the configured axios instance for custom requests if needed
export default apiClient;
