{ ... }:
{
  networking.hostName = "licheerv-nano";
  networking.useDHCP = true;
  time.timeZone = "UTC";

  # Initial access is through UART0 or the USB CDC ACM serial console.
  # Set a password with `passwd` immediately after the first login.
  # Public provisioning password, not a private credential; change on first boot.
  users.users.root.initialHashedPassword = "$6$nixos-sd-image$bV3i6yBkwrTn0eGrX.AmEb6yY1A3NfuOkd65b6y9Xp2DI4wMa7xUhv/kwkf4yr4qWd4VBuPgLlYnJw0oCjXWz/";
  # Add your public SSH key to enable Dropbear. Never put a private key here.
  users.users.root.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 YOUR_PUBLIC_KEY"
  ];

  system.stateVersion = "26.05";
}
