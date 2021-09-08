#!/usr/bin/env sh

dns_onapp_add() {
	fulldomain=$1
	txtvalue=$2
	_info "Using onapp"
	_debug fulldomain "$fulldomain"
	_debug txtvalue "$txtvalue"

	ONAPP_Host="${ONAPP_Host:-$(_readaccountconf_mutable ONAPP_Host)}"
	ONAPP_Username="${ONAPP_Username:-$(_readaccountconf_mutable ONAPP_Username)}"
	ONAPP_Password="${ONAPP_Password:-$(_readaccountconf_mutable ONAPP_Password)}"

	if [ -z "$ONAPP_Host" ] || [ -z "$ONAPP_Username" ] || [ -z "$ONAPP_Password" ]; then
		ONAPP_Host=""
		ONAPP_Username=""
		ONAPP_Password=""
		_err "You didn't specify a OnApp host, username and password yet."
		return 1
	fi

	#save the credentials to the account conf file.
	_saveaccountconf_mutable ONAPP_Host "$ONAPP_Host"
	_saveaccountconf_mutable ONAPP_Username "$ONAPP_Username"
	_saveaccountconf_mutable ONAPP_Password "$ONAPP_Password"

	_debug "First detect the root zone"
	if ! _get_root "$fulldomain"; then
		_err "invalid domain"
		return 1
	fi
	_debug _domain_id "$_domain_id"
	_debug _sub_domain "$_sub_domain"
	_debug _domain "$_domain"

	_info "Adding record"
	if _onapp_rest POST "dns_zones/$_domain_id/records.json" "{\"dns_record\":{\"name\":\"$fulldomain\",\"ttl\":14400,\"type\":\"TXT\",\"txt\":\"$txtvalue\"}}"; then
		if _contains "$response" "$txtvalue"; then
			_info "Added, OK"
			return 0
		fi
	fi
	_err "Add txt record error."
	return 1
}

dns_onapp_rm() {
	fulldomain=$1
	txtvalue=$2
	_info "Using onapp"
	_debug fulldomain "$fulldomain"
	_debug txtvalue "$txtvalue"
}

_get_root() {
	domain=$1
	i=1
	p=1

	if ! _onapp_rest GET "dns_zones.json"; then
		return 1
	fi

	while true; do
		h=$(printf "%s" "$domain" | cut -d . -f $i-100)
		_debug h "$h"
		if [ -z "$h" ]; then
			#not valid
			return 1
		fi

		matching_zone=$(echo "$response" | jq ".[] | .dns_zone | select(.name == \"$h\")")

		if [ "$matching_zone" ]; then
			_domain_id=$(echo "$matching_zone" | jq ".id")

			if [ "$_domain_id" ]; then
				_sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-$p)
				_domain=$h
				return 0
			fi
			return 1
		fi

		p=$i
		i=$(_math "$i" + 1)
	done
	return 1
}

_onapp_rest() {
	method=$1
	endpoint=$2
	data=$3

	username=$(echo "$ONAPP_Username" | tr -d '"')
	password=$(echo "$ONAPP_Password" | tr -d '"')
	token="$(printf "%s" "$username:$password" | _base64)"

	export _H1="Authorization: Basic $token"
	export _H2="Content-Type: application/json"

	if [ "$method" != "GET" ]; then
		_debug data "$data"
		response="$(_post "$data" "$ONAPP_Host/$endpoint" "" "$method")"
	else
		response="$(_get "$ONAPP_Host/$endpoint")"
	fi

	if [ "$?" != "0" ]; then
		_err "error $endpoint"
		return 1
	fi
	_debug2 response "$response"
	return 0
}

