#!/bin/bash
set -eo pipefail

curl -L https://raw.githubusercontent.com/martijnversluis/mac_provisioning/master/Rakefile
rake install
