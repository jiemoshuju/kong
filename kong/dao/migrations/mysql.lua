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
    ]],
    down = [[
      DROP TABLE ssl_certificates;
      DROP TABLE ssl_servers_names;
    ]]
  }
  

}
