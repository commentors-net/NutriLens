import { Alert, Button } from '@mui/material';
import SystemUpdateIcon from '@mui/icons-material/SystemUpdate';

interface UpdateBannerProps {
  visible: boolean;
}

export function UpdateBanner({ visible }: UpdateBannerProps) {
  if (!visible) return null;

  return (
    <Alert
      severity="info"
      icon={<SystemUpdateIcon />}
      action={
        <Button
          color="inherit"
          size="small"
          variant="outlined"
          onClick={() => window.location.reload()}
          sx={{ whiteSpace: 'nowrap' }}
        >
          Reload now
        </Button>
      }
      sx={{ borderRadius: 0, position: 'sticky', top: 0, zIndex: 1200 }}
    >
      A new version is available — reload to get the latest update.
    </Alert>
  );
}
