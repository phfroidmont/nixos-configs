set -euo pipefail

service=com.nextcloudgmbh.Nextcloud
root=/com/nextcloudgmbh/Nextcloud

if ! raw=$(busctl --user --json=short call \
  "$service" "$root" org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null); then
  printf '{"state":"unavailable","tooltip":"Nextcloud is not running","folders":[]}\n'
  exit 0
fi

jq -c '
  [.data[0] | to_entries[]
    | select(.key | startswith("/com/nextcloudgmbh/Nextcloud/Folder/"))
    | .value["org.freedesktop.CloudProviders.Account"]
    | {
        name: (.Name.data // "Nextcloud"),
        path: (.Path.data // ""),
        status: (.Status.data // 0),
        message: (.StatusDetails.data // "")
      }
    | .state = (if .status == 2 then "syncing" elif .status == 3 then "error" else "idle" end)
  ] as $folders
  | (if any($folders[]; .state == "error") then "error"
     elif any($folders[]; .state == "syncing") then "syncing"
     elif ($folders | length) > 0 then "idle"
     else "unavailable"
     end) as $state
  | {
      state: $state,
      folderPath: ($folders[0].path // ""),
      tooltip: (if ($folders | length) == 0 then "Nextcloud is not running"
        else ($folders | map((.name // .path) + ": " + (.message // .state)) | join("\n")) end),
      folders: $folders
    }
' <<<"$raw"
