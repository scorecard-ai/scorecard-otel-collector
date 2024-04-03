Summary:    Scorecard Open Telemetry Collector
Name:       %{RPM_NAME}
Version:    %{VERSION}
Release:    1
License:    Apache 2.0
Group:      Applications/scorecard
Source0:    %{RPM_NAME}-%{VERSION}.tar.gz

%description
This package provides daemon of Scorecard Collector

%prep
%setup -q

%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}
cp -fa * ${RPM_BUILD_ROOT}

%files
%dir /opt/scorecard/scorecard-otel-collector
%dir /opt/scorecard/scorecard-otel-collector/bin
%dir /opt/scorecard/scorecard-otel-collector/doc
%dir /opt/scorecard/scorecard-otel-collector/etc
%dir %attr(750, soc, soc) /opt/scorecard/scorecard-otel-collector/logs
%dir %attr(750, soc, soc) /opt/scorecard/scorecard-otel-collector/var
%dir %attr(750, soc, soc) /opt/scorecard/scorecard-otel-collector/etc

/opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector
/opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector-ctl
/opt/scorecard/scorecard-otel-collector/bin/VERSION
/opt/scorecard/scorecard-otel-collector/LICENSE
%attr(640, soc, soc) /opt/scorecard/scorecard-otel-collector/var/.config.yaml
%attr(640, soc, soc) /opt/scorecard/scorecard-otel-collector/etc/.env

/etc/init/scorecard-otel-collector.conf
/etc/systemd/system/scorecard-otel-collector.service
/usr/bin/scorecard-otel-collector-ctl
/etc/scorecard/scorecard-otel-collector
/var/log/scorecard/scorecard-otel-collector
/var/run/scorecard/scorecard-otel-collector

%pre
# Stop the agent before upgrades.
if [ $1 -ge 2 ]; then
    if [ -x /opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector-ctl ]; then
        /opt/scorecard/scorecard-otel-collector/bin/scorecard-otel-collector-ctl -a stop
    fi
fi

# create group
if ! grep "^soc:" /etc/group >/dev/null 2>&1; then
    groupadd -r soc >/dev/null 2>&1
    echo "create group soc, result: $?"
fi

# create user
if ! id soc >/dev/null 2>&1; then
    useradd -r -M soc -d /home/soc -g soc -c "Scorecard Collector" -s $(test -x /sbin/nologin && echo /sbin/nologin || (test -x /usr/sbin/nologin && echo /usr/sbin/nologin || (test -x /bin/false && echo /bin/false || echo /bin/sh))) >/dev/null 2>&1
    echo "create user soc, result: $?"
fi


%clean
rm -rf ${RPM_BUILD_ROOT}
