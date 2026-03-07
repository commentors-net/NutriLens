
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { TextField, Button, Card, Typography, Box } from "@mui/material";
import { authApi } from "@services/api";

export default function Register() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [qrCode, setQrCode] = useState("");
  const [secret, setSecret] = useState("");
  const navigate = useNavigate();

  const handleRegister = async () => {
    try {
      const res = await authApi.register({ username, password });
      setQrCode(res.qr);
      setSecret(res.secret);
    } catch (err) {
      alert("Registration failed");
    }
  };

  const handleContinueToLogin = () => {
    navigate("/login");
  };

  return (
    <Card sx={{ p: { xs: 2, sm: 3, md: 4 }, maxWidth: 500, width: '100%', mx: "auto", mt: { xs: 4, sm: 6, md: 10 } }}>
      <Typography variant="h6" sx={{ mb: 2 }}>Register</Typography>
      {!qrCode ? (
        <>
          <TextField label="Username" value={username} onChange={e => setUsername(e.target.value)} fullWidth margin="normal" />
          <TextField label="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} fullWidth margin="normal" />
          <Button variant="contained" fullWidth onClick={handleRegister} sx={{ mt: 2 }}>Register</Button>
        </>
      ) : (
        <Box sx={{ textAlign: "center" }}>
          <Typography variant="body1" sx={{ mt: 2, mb: 2 }}>
            Scan this QR code with Google Authenticator or similar app:
          </Typography>
          <img src={`data:image/png;base64,${qrCode}`} alt="QR Code" style={{ maxWidth: "100%" }} />
          <Typography variant="body2" sx={{ mt: 2, mb: 2, wordBreak: "break-all", px: { xs: 1, sm: 0 } }}>
            Secret Key: <strong>{secret}</strong>
          </Typography>
          <Button variant="contained" fullWidth onClick={handleContinueToLogin} sx={{ mt: 2 }}>
            Continue to Login
          </Button>
        </Box>
      )}
    </Card>
  );
}
