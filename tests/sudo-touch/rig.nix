# What tests/sudo-touch/agent-to-pam.test drives in place of a YubiKey and of root:
# `sk-dummy`, OpenSSH's software security key, as a provider ssh-agent loads,
# which waits to sign until the file $SK_DUMMY_TOUCH exists (the touch); and
# pam_wrapper, which runs a PAM stack from a directory of the caller's own, so
# pamtester can run pam_rssh unprivileged.
{ pkgs }:
let
  skDummy = pkgs.stdenv.mkDerivation {
    pname = "sk-dummy";
    inherit (pkgs.openssh) version src;
    buildInputs = [ pkgs.openssl pkgs.zlib ];
    postPatch = ''
      substituteInPlace regress/misc/sk-dummy/sk-dummy.c --replace-fail \
        '	struct sk_sign_response *response = NULL;' \
        '	struct sk_sign_response *response = NULL;
      	{
      		const char *touch = getenv("SK_DUMMY_TOUCH");
      		int i;
      		for (i = 0; touch != NULL && access(touch, F_OK) != 0 && i < 400; i++)
      			usleep(50000);
      	}'
    '';
    configureFlags = [ "--without-zlib-version-check" ];
    buildPhase = ''
      make -j$NIX_BUILD_CORES libssh.a openbsd-compat/libopenbsd-compat.a
      make regress/misc/sk-dummy/sk-dummy.so
    '';
    installPhase = "install -Dm755 regress/misc/sk-dummy/sk-dummy.so $out/lib/sk-dummy.so";
  };

  pamWrapper = pkgs.stdenv.mkDerivation rec {
    pname = "pam_wrapper";
    version = "1.1.7";
    src = pkgs.fetchurl {
      url = "https://ftp.samba.org/pub/cwrap/pam_wrapper-${version}.tar.gz";
      hash = "sha256-0ck+K2h9CINN8OCQJt1j0s5PV3cB1AagE+mor+RpveE=";
    };
    nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
    buildInputs = [ pkgs.linux-pam ];
  };
in
pkgs.runCommand "sudo-touch-rig" { } ''
  mkdir -p $out/lib $out/bin
  ln -s ${skDummy}/lib/sk-dummy.so $out/lib/sk-dummy.so
  ln -s ${pamWrapper}/lib/libpam_wrapper.so $out/lib/libpam_wrapper.so
  ln -s ${pkgs.pam_rssh}/lib/libpam_rssh.so $out/lib/libpam_rssh.so
  ln -s ${pkgs.linux-pam}/lib/security/pam_deny.so $out/lib/pam_deny.so
  ln -s ${pkgs.pamtester}/bin/pamtester $out/bin/pamtester
  ln -s ${pkgs.openssh}/bin/ssh-agent ${pkgs.openssh}/bin/ssh-add ${pkgs.openssh}/bin/ssh-keygen $out/bin/
''
