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
        upstream_url varchar(1000),
        retries smallint NOT NULL DEFAULT 5,
        preserve_host boolean NOT NULL,
        hosts varchar(200),
        uris varchar(200),
        methods varchar(20),
        strip_uri boolean,
        https_only boolean,
        http_if_terminated boolean,
        upstream_connect_timeout integer  DEFAULT 60000,
        upstream_send_timeout integer  DEFAULT 60000,
        upstream_read_timeout integer DEFAULT 60000,
        created_at  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX apis_name_idx(name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

     CREATE TABLE IF NOT EXISTS plugins(
        id varchar(50),
        name varchar(100) NOT NULL,
        api_id varchar(50) ,
        consumer_id varchar(50)  ,
        route_id varchar(50) ,
        service_id varchar(50) ,
        config varchar(10000) NOT NULL,
        enabled boolean NOT NULL,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id, name),
        CONSTRAINT plugins_apiid_fk FOREIGN KEY (api_id) REFERENCES apis(id) ON DELETE CASCADE ,
        CONSTRAINT plugins_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE , 
        CONSTRAINT plugins_routeid_fk FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE ,  
        CONSTRAINT plugins_serviceid_fk FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE ,  

        UNIQUE KEY plugins_id_key(id),
        INDEX plugins_name_idx(name),
        INDEX plugins_api_idx(api_id),
        INDEX plugins_consumer_idx(consumer_id),
        INDEX plugins_route_id_idx(route_id),
        INDEX plugins_service_id_idx(service_id)
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
        PRIMARY KEY(primary_key_value, table_name),
        INDEX ttls_primary_uuid_value_idx (primary_uuid_value)
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
    name = "2016-09-16-141423_upstreams",
    -- Note on the timestamps below; these use a precision of milliseconds
    -- this differs from the other tables above, as they only use second precision.
    -- This differs from the change to the Cassandra entities.
    up = [[

      CREATE TABLE IF NOT EXISTS upstreams(
        id varchar(50) PRIMARY KEY,
        name varchar(100) UNIQUE,
        slots int NOT NULL,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        healthchecks varchar(512) DEFAULT NULL,
        hash_on varchar(512) DEFAULT NULL,
        hash_fallback varchar(512) DEFAULT NULL,
        hash_on_header varchar(512) DEFAULT NULL,
        hash_fallback_header varchar(512) DEFAULT NULL,
        hash_on_cookie varchar(512) DEFAULT NULL,
        hash_on_cookie_path varchar(512) DEFAULT NULL,
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

      CREATE TABLE  IF NOT EXISTS certificates(
        id varchar(50) PRIMARY KEY,
        cert text ,
        `key` text ,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      CREATE TABLE IF NOT EXISTS snis(
        name varchar(100),
        certificate_id varchar(50),
        id varchar(50) PRIMARY KEY,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT snis_certificate_id_fkey FOREIGN KEY (certificate_id) REFERENCES certificates(id) ON DELETE CASCADE,
        UNIQUE KEY snis_name_unique(name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE certificates;
      DROP TABLE snis;
    ]]
  },
  {
    name = "2017-05-19-180200_cluster_events",
    up = [[
      CREATE TABLE IF NOT EXISTS cluster_events (
          id varchar(50) NOT NULL,
          node_id varchar(50) NOT NULL,
          at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          nbf timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          expire_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          channel varchar(512) DEFAULT NULL,
          data varchar(512) DEFAULT NULL,
          PRIMARY KEY (id),
          INDEX idx_cluster_events_at (at),
          INDEX idx_cluster_events_channel (channel)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE IF EXISTS cluster_events;
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
      CREATE TABLE IF NOT EXISTS services (
        id               varchar(50)                       PRIMARY KEY,
        created_at       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        updated_at       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        name             varchar(512)                       UNIQUE,
        retries          smallint(6) DEFAULT NULL,
        protocol         varchar(512) DEFAULT NULL,
        host             varchar(512) DEFAULT NULL,
        port             int(11) DEFAULT NULL,
        path             varchar(512) DEFAULT NULL,
        connect_timeout  int(11) DEFAULT NULL,
        write_timeout    int(11) DEFAULT NULL,
        read_timeout     int(11) DEFAULT NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      CREATE TABLE IF NOT EXISTS routes (
        id             varchar(50)                       PRIMARY KEY,
        created_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        updated_at     timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        protocols      varchar(512) DEFAULT NULL,
        methods        varchar(512) DEFAULT NULL,
        hosts          varchar(512) DEFAULT NULL,
        paths          varchar(512) DEFAULT NULL,
        regex_priority bigint(20) DEFAULT NULL,
        strip_path     boolean,
        preserve_host  boolean,
        service_id     varchar(50),
        CONSTRAINT     routes_fkey_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = nil
  },
  {
    name = "2018-08-20-100500_websites",
    up = [[
      CREATE TABLE IF NOT EXISTS websites (
        id               varchar(50)                       PRIMARY KEY,
        created_at       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        updated_at       timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        name             varchar(512)                       UNIQUE,
        listen           int(11) DEFAULT 80,
        resolver         varchar(512) DEFAULT '',
        root             varchar(512) DEFAULT '',
        locations        text
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = nil
  }
}
