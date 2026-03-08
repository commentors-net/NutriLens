
import { useEffect, useRef, useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { TextField, Button, Card, Typography, Box, Divider } from "@mui/material";
import { authApi } from "@services/api";

declare global {
  interface Window {
    google?: any;
  }
}

export default function Login() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [token, setToken] = useState("");
  const [isGoogleLoading, setIsGoogleLoading] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const googleButtonRef = useRef<HTMLDivElement | null>(null);
  const googleClientId = import.meta.env.VITE_GOOGLE_CLIENT_ID || "";

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
    try {
      const res = await authApi.login({ username, password, token }, system);
      completeLogin(res);
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || "Login failed: Invalid credentials or 2FA token";
      alert(errorMsg);
    }
  };

  useEffect(() => {
    if (!googleClientId || !googleButtonRef.current) {
      return;
    }

    const existingScript = document.getElementById("google-gsi-script");
    const initializeGoogle = () => {
      if (!window.google?.accounts?.id) {
        return;
      }

      window.google.accounts.id.initialize({
        client_id: googleClientId,
        callback: async (response: { credential: string }) => {
          if (!response?.credential) {
            return;
          }
          setIsGoogleLoading(true);
          try {
            const res = await authApi.googleLogin({ id_token: response.credential }, system);
            completeLogin(res);
          } catch (err: any) {
            const errorMsg = err.response?.data?.detail || "Google login failed";
            alert(errorMsg);
          } finally {
            setIsGoogleLoading(false);
          }
        },
      });

      googleButtonRef.current!.innerHTML = "";
      window.google.accounts.id.renderButton(googleButtonRef.current, {
        theme: "outline",
        size: "large",
        width: 320,
        text: "continue_with",
      });
    };

    if (existingScript) {
      initializeGoogle();
      return;
    }

    const script = document.createElement("script");
    script.id = "google-gsi-script";
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.defer = true;
    script.onload = initializeGoogle;
    document.body.appendChild(script);
  }, [googleClientId, system]);

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

      <Divider sx={{ my: 3 }}>OR</Divider>
      {googleClientId ? (
        <Box sx={{ display: "flex", justifyContent: "center", minHeight: 40 }}>
          {isGoogleLoading ? <Typography variant="body2">Signing in with Google...</Typography> : <div ref={googleButtonRef} />}
        </Box>
      ) : (
        <Typography variant="caption" color="text.secondary">
          Google SSO is disabled. Set <code>VITE_GOOGLE_CLIENT_ID</code> to enable it.
        </Typography>
      )}
    </Card>
  );
}
