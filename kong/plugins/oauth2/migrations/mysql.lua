return {
  {
    name = "2015-08-03-132400_init_oauth2",
    up = [[
     CREATE TABLE IF NOT EXISTS oauth2_credentials(
        id varchar(50),
        name varchar(100),
        consumer_id varchar(50) ,
        client_id varchar(100) UNIQUE,
        client_secret varchar(200) UNIQUE,
        redirect_uri varchar(1000),
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        CONSTRAINT oauth2_cred_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE , 
        INDEX oauth2_credentials_consumer_idx(consumer_id),
        INDEX oauth2_credentials_client_idx(client_id),
        INDEX oauth2_credentials_secret_idx(client_secret)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      CREATE TABLE IF NOT EXISTS oauth2_authorization_codes(
        id varchar(50),
        credential_id varchar(50)  ,
        code varchar(100) UNIQUE,
        authenticated_userid varchar(100),
        scope varchar(200),
        api_id varchar(50) , 
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        CONSTRAINT oauth2_authtoken_cred_fk FOREIGN KEY (credential_id) REFERENCES oauth2_credentials(id) ON DELETE CASCADE , 
        CONSTRAINT oauth2_authtoken_apiid_fk FOREIGN KEY (api_id) REFERENCES apis(id) ON DELETE CASCADE , 
        INDEX oauth2_autorization_code_idx(code);
        INDEX oauth2_authorization_userid_idx(authenticated_userid);
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

      CREATE TABLE IF NOT EXISTS oauth2_tokens(
        id varchar(50),
        credential_id varchar(50)  ,
        access_token varchar(200) UNIQUE,
        token_type varchar(50),
        refresh_token varchar(200) UNIQUE,
        expires_in int,
        authenticated_userid varchar(100),
        scope varchar(200),
        api_id varchar(50), 
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        CONSTRAINT oauth2_token_cred_fk FOREIGN KEY (credential_id) REFERENCES oauth2_credentials(id) ON DELETE CASCADE , 
        CONSTRAINT oauth2_token_apiid_fk FOREIGN KEY (api_id) REFERENCES apis(id) ON DELETE CASCADE , 
        INDEX oauth2_accesstoken_idx(access_token),
        INDEX oauth2_token_refresh_idx(refresh_token),
        INDEX oauth2_token_userid_idx(authenticated_userid)

      )ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down =  [[
      DROP TABLE oauth2_credentials;
      DROP TABLE oauth2_authorization_codes;
      DROP TABLE oauth2_tokens;
    ]]
  },
  {
    name = "2016-12-22-283949_serialize_redirect_uri",
    up = function(_, _, factory)
      local schema = factory.oauth2_credentials.schema
      schema.fields.redirect_uri.type = "string"
      local json = require "cjson"
      local apps, err = factory.oauth2_credentials.db:find_all('oauth2_credentials', nil, schema);
      if err then
        return err
      end
      for _, app in ipairs(apps) do
        local redirect_uri = {};
        redirect_uri[1] = app.redirect_uri
        local redirect_uri_str = json.encode(redirect_uri)
        local req = "UPDATE oauth2_credentials SET redirect_uri='"..redirect_uri_str.."' WHERE id='"..app.id.."'"
        local _, err = factory.oauth2_credentials.db:queries(req)
        if err then
          return err
        end
      end
      schema.fields.redirect_uri.type = "array"
    end,
    down = function(_,_,factory)
      local apps, err = factory.oauth2_credentials:find_all()
      if err then
        return err
      end
      for _, app in ipairs(apps) do
        local redirect_uri = app.redirect_uri[1]
        local req = "UPDATE oauth2_credentials SET redirect_uri='"..redirect_uri.."' WHERE id='"..app.id.."'"
        local _, err = factory.oauth2_credentials.db:queries(req)
        if err then
          return err
        end
      end
    end
  },
  {
    name = "2016-12-15-set_global_credentials",
    up = function(_, _, dao)
      local rows, err = dao.plugins:find_all({name = "oauth2"})
      if err then return err end
      for _, row in ipairs(rows) do
        row.config.global_credentials = true

        local _, err = dao.plugins:update(row, row)
        if err then return err end
      end
    end
  }
}
