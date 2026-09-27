import { StrictMode, useMemo } from 'react';
import { createRoot } from 'react-dom/client';
import { createAppContainer, isWebConfigured } from './app/container';
import { AuthProvider } from './app/providers/auth_provider';
import { AppRouter } from './app/router';
import { ConfirmProvider } from './shared/ui/confirm_dialog';
import { SetupScreen } from './features/setup/screens/setup_screen';
import './index.css';

function Root() {
  const configured = isWebConfigured();
  const container = useMemo(
    () => (configured ? createAppContainer() : null),
    [configured],
  );

  if (!container) {
    return <SetupScreen />;
  }

  return (
    <AuthProvider container={container}>
      <AppRouter />
    </AuthProvider>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ConfirmProvider>
      <Root />
    </ConfirmProvider>
  </StrictMode>,
);
