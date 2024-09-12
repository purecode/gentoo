# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# To create the go modules tarball:
#   cd src/go
#   GOMODCACHE="${PWD}"/go-mod go mod download -modcacherw
#   tar -acf $(pwd | grep -Eo 'zabbix-[0-9.]+')-go-deps.tar.xz go-mod

EAPI=8

# needed to make webapp-config dep optional
inherit autotools systemd tmpfiles toolchain-funcs

DESCRIPTION="ZABBIX is software for monitoring of your applications, network and servers"
HOMEPAGE="https://www.zabbix.com/"
MY_P=${P/_/}
MY_PV=${PV/_/}
SRC_URI="https://cdn.zabbix.com/zabbix/sources/stable/$(ver_cut 1-2)/zabbix-$(ver_cut 1-4).tar.gz"

S=${WORKDIR}/zabbix-$(ver_cut 1-4)

LICENSE="AGPL-3"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="amd64 ~arm64 ~x86"
IUSE="+agent gnutls +openssl"
REQUIRED_USE="|| ( agent )
	?? ( gnutls openssl )"

COMMON_DEPEND="
	gnutls? ( net-libs/gnutls:0= )
	openssl? ( dev-libs/openssl:=[-bindist(-)] )
"

RDEPEND="${COMMON_DEPEND}
	acct-group/zabbix
	acct-user/zabbix
"
DEPEND="${COMMON_DEPEND}"
BDEPEND="
	virtual/pkgconfig
"

# upstream tests fail for agent2
RESTRICT="test"

PATCHES=()

src_prepare() {
	default

	# Since we patch configure.ac with e.g., ${PN}-6.4.0-configure-sscanf.patch".
	eautoreconf
}

src_configure() {
	local econf_args=(
		--with-libpcre2
		"$(use_enable agent)"
		"$(use_with gnutls)"
		"$(use_with openssl)"
	)

	econf ${econf_args[@]}
}

src_compile() {
	if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]; then
		emake AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)"
	fi
}

src_install() {
	local dirs=(
		/etc/zabbix
		/var/lib/zabbix
		/var/log/zabbix
	)

	for dir in "${dirs[@]}"; do
		keepdir "${dir}"
	done

	if use agent; then
		insinto /etc/zabbix
		doins "${S}"/conf/zabbix_agentd.conf
		fperms 0640 /etc/zabbix/zabbix_agentd.conf
		fowners root:zabbix /etc/zabbix/zabbix_agentd.conf

		newinitd "${FILESDIR}"/zabbix-agentd.init zabbix-agentd

		dosbin src/zabbix_agent/zabbix_agentd
		dobin \
			src/zabbix_sender/zabbix_sender \
			src/zabbix_get/zabbix_get

		systemd_dounit "${FILESDIR}"/zabbix-agentd.service
		newtmpfiles "${FILESDIR}"/zabbix-agentd.tmpfiles zabbix-agentd.conf
	fi

	fowners root:zabbix /etc/zabbix
	fowners zabbix:zabbix \
		/var/lib/zabbix \
		/var/log/zabbix
	fperms 0750 \
		/etc/zabbix \
		/var/lib/zabbix \
		/var/log/zabbix

	dodoc README INSTALL NEWS ChangeLog \
		conf/zabbix_agentd.conf \
		conf/zabbix_agentd/userparameter_examples.conf \
		conf/zabbix_agentd/userparameter_mysql.conf

}

pkg_postinst() {
	if use agent; then
		tmpfiles_process zabbix-agentd.conf
	fi

	elog "--"
	elog
	elog "You may need to add these lines to /etc/services:"
	elog
	elog "zabbix-agent     10050/tcp Zabbix Agent"
	elog "zabbix-agent     10050/udp Zabbix Agent"
	elog "zabbix-trapper   10051/tcp Zabbix Trapper"
	elog "zabbix-trapper   10051/udp Zabbix Trapper"
	elog
}
