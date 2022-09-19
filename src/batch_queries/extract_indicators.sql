with maxmind AS (
  SELECT 
     network,
     geoname_id,
     is_anonymous_proxy,
     latitude,
     longitude,
     continent_name,
     country_name,
     city_name,
     NET.IP_FROM_STRING(REGEXP_EXTRACT(network, r'(.*)/' )) network_bin,
     CAST(REGEXP_EXTRACT(network, r'/(.*)' ) AS INT64) mask,
     autonomous_system_number,
     autonomous_system_organization
FROM `twitter-iocs.maxmind.geolite_city_blocks` 
JOIN `twitter-iocs.maxmind.geolite_city_locations_en` USING (geoname_id)
LEFT JOIN `twitter-iocs.maxmind.geolite_asn` USING (network)
),
ips AS (
  SELECT
    id,
    -- Extract IP and replace defanged brackets
    REGEXP_REPLACE(
      REGEXP_EXTRACT(text, r'((?:\d{1,3}\[?\.\]?)+\d{1,3})'),
      r"\[|\]", ""
     ) AS ip,
  FROM `twitter-iocs.iocs.tweets`
),
ips_with_masks AS (
  SELECT
    id,
    ip,
    NET.SAFE_IP_FROM_STRING(ip) & NET.IP_NET_MASK(4, mask) network_bin,
    mask
  FROM ips, UNNEST(GENERATE_ARRAY(8,32)) mask
)
SELECT
  id,
  ips_with_masks.ip,
  maxmind.geoname_id,
  maxmind.is_anonymous_proxy,
  maxmind.latitude,
  maxmind.longitude,
  maxmind.continent_name,
  maxmind.country_name,
  maxmind.city_name,
  maxmind.autonomous_system_number,
  maxmind.autonomous_system_organization
FROM ips_with_masks
JOIN maxmind USING (network_bin, mask)
-- Have we already processed this event before?
LEFT JOIN `twitter-iocs.iocs.indicators` indicators USING (id)
WHERE indicators.id IS NULL