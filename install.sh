#!/bin/bash
set -eo pipefail

mkdir mac_provisioning
cd mac_provisioning
curl -L https://raw.githubusercontent.com/martijnversluis/mac_provisioning/master/Rakefile > Rakefile
rake install
