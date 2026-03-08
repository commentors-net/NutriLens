import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { TextField, Button, Card, Typography, Box, Divider, Alert } from "@mui/material";
import { GoogleLogin, CredentialResponse } from '@react-oauth/google';
import { authApi } from "@services/api";
import { config } from "@/config";

export default function Login() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [token, setToken] = useState("");
  const [error, setError] = useState<string>("");
  const [isGoogleLoading, setIsGoogleLoading] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  const isNutriLens = location.pathname.includes("/nutrilens/");
  const system: "" | "leave-tracker" | "nutrilens" = isNutriLens
    ? "nutrilens"
    : "leave-tracker";

  const completeLogin = (res: {
    access_token: string;
    username: string;
    allowed_systems: string[];
  }) => {
    localStorage.setItem("access_token", res.access_token);
    localStorage.setItem("username", res.username);
    localStorage.setItem("allowed_systems", JSON.stringify(res.allowed_systems || []));
    localStorage.removeItem("selected_system");
    window.dispatchEvent(new Event("storage"));
    navigate("/app-select");
  };

  const handleLogin = async () => {
    setError("");
    try {
      const res = await authApi.login({ username, password, token }, system);
      completeLogin(res);
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || "Login failed: Invalid credentials or 2FA token";
      setError(errorMsg);
    }
  };

  const handleGoogleSuccess = async (credentialResponse: CredentialResponse) => {
    if (!credentialResponse.credential) {
      setError("Google login failed: No credential received");
      return;
    }
    
    setError("");
    setIsGoogleLoading(true);
    try {
      const res = await authApi.googleLogin(
        { id_token: credentialResponse.credential },
        system
      );
      completeLogin(res);
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || "Google login failed";
      setError(errorMsg);
    } finally {
      setIsGoogleLoading(false);
    }
  };

  const handleGoogleError = () => {
    setError("Google login failed. Please try again.");
  };

  return (
    <Card sx={{ p: { xs: 2, sm: 3, md: 4 }, maxWidth: 400, width: '100%', mx: "auto", mt: { xs: 4, sm: 6, md: 10 } }}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        {isNutriLens ? "NutriLens Login" : "Leave Tracker Login"}
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <TextField 
        label="Username" 
        value={username} 
        onChange={e => setUsername(e.target.value)} 
        fullWidth 
        margin="normal"
        onKeyPress={(e) => e.key === 'Enter' && handleLogin()}
      />
      <TextField 
        label="Password" 
        type="password"
        value={password} 
        onChange={e => setPassword(e.target.value)} 
        fullWidth 
        margin="normal"
        onKeyPress={(e) => e.key === 'Enter' && handleLogin()}
      />
      <TextField 
        label="2FA Token" 
        value={token} 
        onChange={e => setToken(e.target.value)} 
        fullWidth 
        margin="normal"
        onKeyPress={(e) => e.key === 'Enter' && handleLogin()}
      />
      <Button variant="contained" fullWidth onClick={handleLogin} sx={{ mt: 2 }}>
        Login
      </Button>

      <Divider sx={{ my: 3 }}>OR</Divider>

      {config.googleClientId ? (
        <Box sx={{ display: "flex", justifyContent: "center", minHeight: 40 }}>
          {isGoogleLoading ? (
            <Typography variant="body2">Signing in with Google...</Typography>
          ) : (
            <GoogleLogin
              onSuccess={handleGoogleSuccess}
              onError={handleGoogleError}
              useOneTap
              theme="outline"
              size="large"
              text="continue_with"
              width="320"
            />
          )}
        </Box>
      ) : (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', textAlign: 'center' }}>
          Google SSO is disabled. Set <code>VITE_GOOGLE_CLIENT_ID</code> in .env to enable it.
        </Typography>
      )}
    </Card>
  );
}
