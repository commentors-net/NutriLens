
import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { TextField, Button, Card, Typography } from "@mui/material";
import { authApi } from "@services/api";

export default function Login() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [token, setToken] = useState("");
  const navigate = useNavigate();
  const location = useLocation();

  const isNutriLens = location.pathname.includes("/nutrilens/");
  const system: "" | "leave-tracker" | "nutrilens" = isNutriLens
    ? "nutrilens"
    : "leave-tracker";

  const handleLogin = async () => {
    try {
      const res = await authApi.login({ username, password, token }, system);
      
      // Store JWT token in localStorage
      localStorage.setItem("access_token", res.access_token);
      localStorage.setItem("username", res.username);
      localStorage.setItem("selected_system", isNutriLens ? "nutrilens" : "leave-tracker");
      
      // Trigger storage event for app state update
      window.dispatchEvent(new Event('storage'));
      
      alert("Login successful!");
      // Redirect by selected system
      navigate(isNutriLens ? "/nutrilens" : "/dashboard");
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || "Login failed: Invalid credentials or 2FA token";
      alert(errorMsg);
    }
  };

  return (
    <Card sx={{ p: { xs: 2, sm: 3, md: 4 }, maxWidth: 400, width: '100%', mx: "auto", mt: { xs: 4, sm: 6, md: 10 } }}>
      <Typography variant="h6" sx={{ mb: 2 }}>
        {isNutriLens ? "NutriLens Login" : "Leave Tracker Login"}
      </Typography>
      <TextField label="Username" value={username} onChange={e => setUsername(e.target.value)} fullWidth margin="normal" />
      <TextField 
        label="Password" 
        type="password"
        value={password} 
        onChange={e => setPassword(e.target.value)} 
        fullWidth 
        margin="normal" 
      />
      <TextField label="2FA Token" value={token} onChange={e => setToken(e.target.value)} fullWidth margin="normal" />
      <Button variant="contained" fullWidth onClick={handleLogin} sx={{ mt: 2 }}>Login</Button>
    </Card>
  );
}
