local utils = require "kong.tools.utils"

return {
  {
    name = "2015-01-12-175310_skeleton",
    up = function(db, properties)
      return db:queries [[
        CREATE TABLE IF NOT EXISTS schema_migrations(
          id varchar(100) PRIMARY KEY,
          migrations varchar(10000)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
      ]]
    end,
    down = [[
      DROP TABLE schema_migrations;
    ]]
  },
  {
    name = "2015-01-12-175310_init_schema",
    up = [[

        CREATE TABLE IF NOT EXISTS consumers(
        id varchar(50) PRIMARY KEY,
        custom_id varchar(100) UNIQUE,
        username varchar(100) UNIQUE,
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX custom_id_idx(custom_id),
        INDEX username_idx(username)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

        CREATE TABLE IF NOT EXISTS apis(
        id varchar(50) PRIMARY KEY,
        name varchar(100) UNIQUE,
        request_host varchar(100) UNIQUE,
        request_path varchar(100) UNIQUE,
        strip_request_path boolean NOT NULL,
        upstream_url varchar(1000),
        preserve_host boolean NOT NULL,
        created_at  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX apis_name_idx(name),
        INDEX apis_request_host_idx(request_host),
        INDEX apis_request_path_idx(request_path),
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

     CREATE TABLE IF NOT EXISTS plugins(
        id varchar(50),
        name varchar(100) NOT NULL,
        api_id varchar(50) ,
        consumer_id varchar(50)  ,
        config varchar(10000) NOT NULL,
        enabled boolean NOT NULL,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id, name),
        CONSTRAINT plugins_apiid_fk FOREIGN KEY (api_id) REFERENCES apis(id) ON DELETE CASCADE ,
        CONSTRAINT plugins_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE ,  
        INDEX plugins_name_idx(name),
        INDEX plugins_api_idx(api_id),
        INDEX plugins_consumer_idx(consumer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE consumers;
      DROP TABLE apis;
      DROP TABLE plugins;
    ]]
  },
  {
    name = "2015-11-23-817313_nodes",
    up = [[
     CREATE TABLE IF NOT EXISTS nodes(
        name varchar(100),
        cluster_listening_address varchar(500),
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (name),
        INDEX nodes_cluster_listening_address_idx(cluster_listening_address)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC ;

    ]],
    down = [[
      DROP TABLE nodes;
    ]]
  },


  {
    name = "2016-02-29-142793_ttls",
    up = [[
      CREATE TABLE IF NOT EXISTS ttls(
        primary_key_value varchar(200) NOT NULL,
        primary_uuid_value varchar(50),
        table_name varchar(100) NOT NULL,
        primary_key_name varchar(100) NOT NULL,
        expire_at timestamp  NOT NULL,
        PRIMARY KEY(primary_key_value, table_name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      CREATE FUNCTION upsert_ttl(v_primary_key_value varchar(200), v_primary_uuid_value varchar(50), v_primary_key_name varchar(100), v_table_name varchar(100), v_expire_at timestamp)  RETURNS INT
        BEGIN
            IF EXISTS(SELECT * FROM ttls WHERE primary_key_value = v_primary_key_value AND table_name = v_table_name ) THEN
               UPDATE ttls SET expire_at = v_expire_at WHERE primary_key_value = v_primary_key_value AND table_name = v_table_name;
            ELSE
              INSERT INTO ttls(primary_key_value, primary_uuid_value, primary_key_name, table_name, expire_at) VALUES(v_primary_key_value, v_primary_uuid_value, v_primary_key_name, v_table_name, v_expire_at);
            END IF; 
            RETURN 1;
      END;
       
    ]],
    down = [[
      DROP TABLE ttls;
      DROP FUNCTION upsert_ttl;
    ]]
  },
  {
    name = "2016-09-05-212515_retries",
    up = [[
      delimiter $$
      BEGIN
        ALTER TABLE apis ADD retries smallint NOT NULL DEFAULT 5;
      END $$
      delimiter ;
    ]],
    down = [[
      ALTER TABLE apis DROP retries;
    ]]
  },

  {
    name = "2016-09-16-141423_upstreams",
    -- Note on the timestamps below; these use a precision of milliseconds
    -- this differs from the other tables above, as they only use second precision.
    -- This differs from the change to the Cassandra entities.
    up = [[

      CREATE TABLE IF NOT EXISTS upstreams(
        id varchar(50) PRIMARY KEY,
        name varchar(100) UNIQUE,
        slots int NOT NULL,
        orderlist varchar(1000) NOT NULL,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX upstreams_name_idx(name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    
      CREATE TABLE IF NOT EXISTS targets(
        id varchar(50) PRIMARY KEY,
        target varchar(500) NOT NULL,
        weight int NOT NULL,
        upstream_id varchar(50),
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT tragets_upstreamid_fk FOREIGN KEY (upstream_id) REFERENCES upstreams(id) ON DELETE CASCADE ,
        INDEX targets_target_idx(target)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
      
    ]],
    down = [[
      DROP TABLE upstreams;
      DROP TABLE targets;
    ]],
  },
  {
    name = "2016-12-14-172100_move_ssl_certs_to_core",
    up = [[

      CREATE TABLE  IF NOT EXISTS ssl_certificates(
        id varchar(50) PRIMARY KEY,
        cert varchar(500) ,
        `key` varchar(500) ,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      CREATE TABLE IF NOT EXISTS ssl_servers_names(
        name varchar(100) PRIMARY KEY,
        ssl_certificate_id varchar(50),
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT serversname_certificates_fk FOREIGN KEY (ssl_certificate_id) REFERENCES ssl_certificates(id) ON DELETE CASCADE 
    
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      ALTER TABLE apis ADD https_only boolean;
      ALTER TABLE apis ADD http_if_terminated boolean;
    ]],
    down = [[
      DROP TABLE ssl_certificates;
      DROP TABLE ssl_servers_names;

      ALTER TABLE apis DROP https_only;
      ALTER TABLE apis DROP http_if_terminated;
    ]]
  },
  {
    name = "2016-11-11-151900_new_apis_router_1",
    up = [[
      delimiter $$
      BEGIN
        ALTER TABLE apis ADD hosts varchar(200);
        ALTER TABLE apis ADD uris varchar(200);
        ALTER TABLE apis ADD methods varchar(20);
        ALTER TABLE apis ADD strip_uri boolean;
      END $$;
      delimiter ;
    ]],
    down = [[
      ALTER TABLE apis DROP hosts;
      ALTER TABLE apis DROP uris;
      ALTER TABLE apis DROP methods;
      ALTER TABLE apis DROP strip_uri;
    ]]
  },
  {
    name = "2016-11-11-151900_new_apis_router_2",
    up = function(_, _, dao)
      -- create request_headers and request_uris
      -- with one entry each: the current request_host
      -- and the current request_path
      -- We use a raw SQL query because we removed the
      -- request_host/request_path fields in the API schema,
      -- hence the Postgres DAO won't include them in the
      -- retrieved rows.
      local rows, err = dao.db:query([[
        SELECT * FROM apis;
      ]])
      if err then
        return err
      end

      local fmt = string.format
      local cjson = require("cjson")

      for _, row in ipairs(rows) do
        local set = {}

        local upstream_url = row.upstream_url
        while string.sub(upstream_url, #upstream_url) == "/" do
          upstream_url = string.sub(upstream_url, 1, #upstream_url - 1)
        end
        set[#set + 1] = fmt("upstream_url = '%s'", upstream_url)

        if row.request_host and row.request_host ~= "" then
          set[#set + 1] = fmt("hosts = '%s'",
                              cjson.encode({ row.request_host }))
        end

        if row.request_path and row.request_path ~= "" then
          set[#set + 1] = fmt("uris = '%s'",
                              cjson.encode({ row.request_path }))
        end

        set[#set + 1] = fmt("strip_uri = %s", tostring(row.strip_request_path))

        if #set > 0 then
          local query = [[UPDATE apis SET %s WHERE id = '%s';]]
          local _, err = dao.db:query(
            fmt(query, table.concat(set, ", "), row.id)
          )
          if err then
            return err
          end
        end
      end
    end,
    down = function(_, _, dao)
      -- re insert request_host and request_path from
      -- the first element of request_headers and
      -- request_uris

    end
  },
  {
    name = "2016-11-11-151900_new_apis_router_3",
    up = [[
      ALTER TABLE apis DROP INDEX apis_request_host_idx;
      ALTER TABLE apis DROP INDEX apis_request_path_idx;

      ALTER TABLE apis DROP request_host;
      ALTER TABLE apis DROP request_path;
      ALTER TABLE apis DROP strip_request_path;
    ]],
    down = [[
      ALTER TABLE apis ADD request_host text;
      ALTER TABLE apis ADD request_path text;
      ALTER TABLE apis ADD strip_request_path boolean;

      CREATE INDEX IF NOT EXISTS ON apis(request_host);
      CREATE INDEX IF NOT EXISTS ON apis(request_path);
    ]]
  },
  {
    name = "2016-01-25-103600_unique_custom_id",
    up = [[
      delimiter $$
      BEGIN
        ALTER TABLE consumers ADD CONSTRAINT consumers_custom_id_key UNIQUE(custom_id);
      END $$;
      delimiter ;
    ]],
    down = [[
      ALTER TABLE consumers DROP CONSTRAINT consumers_custom_id_key;
    ]],
  },
  {
    name = "2017-01-24-132600_upstream_timeouts",
    up = [[
      ALTER TABLE apis ADD upstream_connect_timeout integer;
      ALTER TABLE apis ADD upstream_send_timeout integer;
      ALTER TABLE apis ADD upstream_read_timeout integer;
    ]],
    down = [[
      ALTER TABLE apis DROP upstream_connect_timeout;
      ALTER TABLE apis DROP upstream_send_timeout;
      ALTER TABLE apis DROP upstream_read_timeout;
    ]]
  },
  {
    name = "2017-01-24-132600_upstream_timeouts_2",
    up = function(_, _, dao)
      local rows, err = dao.db:query([[
        SELECT * FROM apis;
      ]])
      if err then
        return err
      end

      for _, row in ipairs(rows) do
        if not row.upstream_connect_timeout
          or not row.upstream_read_timeout
          or not row.upstream_send_timeout then

          local _, err = dao.apis:update({
            upstream_connect_timeout = 60000,
            upstream_send_timeout = 60000,
            upstream_read_timeout = 60000,
          }, { id = row.id })
          if err then
            return err
          end
        end
      end
    end,
    down = function(_, _, dao) end
  },
  {
    name = "2017-03-27-132300_anonymous",
    -- this should have been in 0.10, but instead goes into 0.10.1 as a bugfix
    up = function(_, _, dao)
      local cjson = require "cjson"

      for _, name in ipairs({
        "basic-auth",
        "hmac-auth",
        "jwt",
        "key-auth",
        "ldap-auth",
        "oauth2",
      }) do
        local q = string.format("SELECT id, config FROM plugins WHERE name = '%s'",
                                name)

        local rows, err = dao.db:query(q)
        if err then
          return err
        end

        for _, row in ipairs(rows) do
          local config = cjson.decode(row.config)

          if not config.anonymous then
            config.anonymous = ""

            local q = string.format("UPDATE plugins SET config = '%s' WHERE id = '%s'",
                                    cjson.encode(config), row.id)

            local _, err = dao.db:query(q)
            if err then
              return err
            end
          end
        end
      end
    end,
    down = function(_, _, dao) end
  },
  {
    name = "2017-04-18-153000_unique_plugins_id",
    up = function(_, _, dao)
      local duplicates, err = dao.db:query([[
        SELECT plugins.*
        FROM plugins
        JOIN (
          SELECT id
          FROM plugins
          GROUP BY id
          HAVING COUNT(1) > 1)
        AS x
        USING (id)
        ORDER BY id, name;
      ]])
      if err then
        return err
      end

      -- we didnt find any duplicates; we're golden!
      if #duplicates == 0 then
        return
      end

      -- print a human-readable output of all the plugins with conflicting ids
      local t = {}
      t[#t + 1] = "\n\nPlease correct the following duplicate plugin entries and re-run this migration:\n"
      for i = 1, #duplicates do
        local d = duplicates[i]
        local p = {}
        for k, v in pairs(d) do
          p[#p + 1] = k .. ": " .. tostring(v)
        end
        t[#t + 1] = table.concat(p, "\n")
        t[#t + 1] = "\n"
      end

      return table.concat(t, "\n")
    end,
    down = function(_, _, dao) return end
  },
  {
    name = "2017-04-18-153000_unique_plugins_id_2",
    up = [[
      ALTER TABLE plugins ADD CONSTRAINT plugins_id_key UNIQUE(id);
    ]],
    down = [[
      ALTER TABLE plugins DROP CONSTRAINT plugins_id_key;
    ]],
  },
  {
    name = "2017-05-19-180200_cluster_events",
    up = [[
      CREATE TABLE IF NOT EXISTS cluster_events (
          id varchar(50) PRIMARY KEY,
          node_id varchar(50) NOT NULL,
          at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          nbf TIMESTAMP WITH TIME ZONE,
          expire_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          channel text,
          data text,
          INDEX idx_cluster_events_at(at),
          INDEX idx_cluster_events_channel(channel),
      );

      delimiter $$

      CREATE OR REPLACE FUNCTION delete_expired_cluster_events() RETURNS trigger
          AS $$
      BEGIN
          DELETE FROM cluster_events WHERE expire_at <= NOW();
          RETURN NEW;
      END;
      $$;
      delimiter ;

      delimiter $$
      BEGIN
          IF NOT EXISTS(
              SELECT FROM information_schema.triggers
               WHERE event_object_table = 'cluster_events'
                 AND trigger_name = 'delete_expired_cluster_events_trigger')
          THEN
              CREATE TRIGGER delete_expired_cluster_events_trigger
               AFTER INSERT ON cluster_events
               EXECUTE PROCEDURE delete_expired_cluster_events();
          END IF;
      END;
      $$;
      delimiter ;
    ]],
    down = [[
      DROP TABLE IF EXISTS cluster_events;
      DROP FUNCTION IF EXISTS delete_expired_cluster_events;
      DROP TRIGGER IF EXISTS delete_expired_cluster_events_trigger;
    ]],
  },
  {
    name = "2017-05-19-173100_remove_nodes_table",
    up = [[
      DELETE FROM ttls WHERE table_name = 'nodes';

      DROP TABLE nodes;
    ]],
  },
  {
    name = "2017-06-16-283123_ttl_indexes",
    up = [[
      delimiter $$
      BEGIN
        IF (SELECT to_regclass('ttls_primary_uuid_value_idx')) IS NULL THEN
          CREATE INDEX ttls_primary_uuid_value_idx ON ttls(primary_uuid_value);
        END IF;
      END$$;
      delimiter ;
    ]],
    down = [[
      ALTER TABLE ttls DROP INDEX ttls_primary_uuid_value_idx;
    ]]
  },
  {
    name = "2017-07-28-225000_balancer_orderlist_remove",
    up = [[
      ALTER TABLE upstreams DROP orderlist;
    ]],
    down = function(_, _, dao) end  -- not implemented
  },
  {
    name = "2017-11-07-192000_upstream_healthchecks",
    up = [[
      delimiter $$
      BEGIN
          ALTER TABLE upstreams ADD healthchecks varchar(10000);
      END$$;
      delimiter ;
    ]],
    down = [[
      ALTER TABLE upstreams DROP healthchecks;
    ]]
  },
  {
    name = "2017-10-27-134100_consistent_hashing_1",
    up = [[
      ALTER TABLE upstreams ADD hash_on varchar(200);
      ALTER TABLE upstreams ADD hash_fallback varchar(200);
      ALTER TABLE upstreams ADD hash_on_header varchar(200);
      ALTER TABLE upstreams ADD hash_fallback_header varchar(200);
    ]],
    down = [[
      ALTER TABLE upstreams DROP hash_on;
      ALTER TABLE upstreams DROP hash_fallback;
      ALTER TABLE upstreams DROP hash_on_header;
      ALTER TABLE upstreams DROP hash_fallback_header;
    ]]
  },
  {
    name = "2017-11-07-192100_upstream_healthchecks_2",
    up = function(_, _, dao)
      local rows, err = dao.db:query([[
        SELECT * FROM upstreams;
      ]])
      if err then
        return err
      end

      local upstreams = require("kong.dao.schemas.upstreams")
      local default = upstreams.fields.healthchecks.default

      for _, row in ipairs(rows) do
        if not row.healthchecks then
          local _, err = dao.upstreams:update({
            healthchecks = default,
          }, { id = row.id })
          if err then
            return err
          end
        end
      end
    end,
    down = function(_, _, dao) end
  },
  {
    name = "2017-10-27-134100_consistent_hashing_2",
    up = function(_, _, dao)
      local rows, err = dao.db:query([[
        SELECT * FROM upstreams;
      ]])
      if err then
        return err
      end

      for _, row in ipairs(rows) do
        if not row.hash_on or not row.hash_fallback then
          row.hash_on = "none"
          row.hash_fallback = "none"
          row.created_at = nil
          local _, err = dao.upstreams:update(row, { id = row.id })
          if err then
            return err
          end
        end
      end
    end,
    down = function(_, _, dao) end  -- n.a. since the columns will be dropped
  },
  {
    name = "2017-09-14-121200_routes_and_services",
    up = [[
      CREATE TABLE IF NOT EXISTS "services" (
        "id"               varchar(50)                       PRIMARY KEY,
        "created_at"       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        "updated_at"       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        "name"             TEXT                       UNIQUE,
        "retries"          BIGINT,
        "protocol"         TEXT,
        "host"             TEXT,
        "port"             BIGINT,
        "path"             TEXT,
        "connect_timeout"  BIGINT,
        "write_timeout"    BIGINT,
        "read_timeout"     BIGINT
      );

      CREATE TABLE IF NOT EXISTS "routes" (
        "id"             varchar(50)                       PRIMARY KEY,
        "created_at"     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        "updated_at"     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        "protocols"      TEXT[],
        "methods"        TEXT[],
        "hosts"          TEXT[],
        "paths"          TEXT[],
        "regex_priority" BIGINT,
        "strip_path"     BOOLEAN,
        "preserve_host"  BOOLEAN,
        "service_id"     varchar(50)                       REFERENCES "services" ("id")
      );
      DO $$
      BEGIN
        IF (SELECT to_regclass('routes_fkey_service') IS NULL) THEN
          CREATE INDEX "routes_fkey_service"
                    ON "routes" ("service_id");
        END IF;
      END$$;
    ]],
    down = nil
  },
  {
    name = "2017-10-25-180700_plugins_routes_and_services",
    up = [[
      ALTER TABLE plugins ADD route_id uuid REFERENCES routes(id) ON DELETE CASCADE;
      ALTER TABLE plugins ADD service_id uuid REFERENCES services(id) ON DELETE CASCADE;

      DO $$
      BEGIN
        IF (SELECT to_regclass('plugins_route_id_idx')) IS NULL THEN
          CREATE INDEX plugins_route_id_idx ON plugins(route_id);
        END IF;
        IF (SELECT to_regclass('plugins_service_id_idx')) IS NULL THEN
          CREATE INDEX plugins_service_id_idx ON plugins(service_id);
        END IF;
      END$$;
    ]],
    down = nil
  },
  {
    name = "2018-03-27-123400_prepare_certs_and_snis",
    up = [[
      DO $$
      BEGIN
        ALTER TABLE ssl_certificates    RENAME TO certificates;
        ALTER TABLE ssl_servers_names   RENAME TO snis;
      EXCEPTION WHEN duplicate_table THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        ALTER TABLE snis RENAME COLUMN ssl_certificate_id TO certificate_id;
        ALTER TABLE snis ADD    COLUMN id uuid;
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        ALTER TABLE snis ALTER COLUMN created_at TYPE timestamp with time zone
          USING created_at AT time zone 'UTC';
        ALTER TABLE certificates ALTER COLUMN created_at TYPE timestamp with time zone
          USING created_at AT time zone 'UTC';
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
    down = nil
  },
  {
    name = "2018-03-27-125400_fill_in_snis_ids",
    up = function(_, _, dao)
      local fmt = string.format

      local rows, err = dao.db:query([[
        SELECT * FROM snis;
      ]])
      if err then
        return err
      end
      local sql_buffer = { "BEGIN;" }
      local len = #rows
      for i = 1, len do
        sql_buffer[i + 1] = fmt("UPDATE snis SET id = '%s' WHERE name = '%s';",
                                utils.uuid(),
                                rows[i].name)
      end
      sql_buffer[len + 2] = "COMMIT;"

      local _, err = dao.db:query(table.concat(sql_buffer))
      if err then
        return err
      end
    end,
    down = nil
  },
  {
    name = "2018-03-27-130400_make_ids_primary_keys_in_snis",
    up = [[
      ALTER TABLE snis
        DROP CONSTRAINT IF EXISTS ssl_servers_names_pkey;

      ALTER TABLE snis
        DROP CONSTRAINT IF EXISTS ssl_servers_names_ssl_certificate_id_fkey;

      DO $$
      BEGIN
        ALTER TABLE snis
          ADD CONSTRAINT snis_name_unique UNIQUE(name);

        ALTER TABLE snis
          ADD PRIMARY KEY (id);

        ALTER TABLE snis
          ADD CONSTRAINT snis_certificate_id_fkey
          FOREIGN KEY (certificate_id)
          REFERENCES certificates;
      EXCEPTION WHEN duplicate_table THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
    down = nil
  },
  {
    name = "2018-05-17-173100_hash_on_cookie",
    up = [[
      ALTER TABLE upstreams ADD hash_on_cookie text;
      ALTER TABLE upstreams ADD hash_on_cookie_path text;
    ]],
    down = [[
      ALTER TABLE upstreams DROP hash_on_cookie;
      ALTER TABLE upstreams DROP hash_on_cookie_path;
    ]]
  }
}
