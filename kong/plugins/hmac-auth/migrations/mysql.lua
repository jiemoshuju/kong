return {
  {
    name = "2015-09-16-132400_init_hmacauth",
    up = [[
      CREATE TABLE IF NOT EXISTS hmacauth_credentials(
        id varchar(50),
        consumer_id varchar(50)  ,
        username varchar(200) UNIQUE,
        secret varchar(500),
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
         CONSTRAINT hmacauth_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE , 
        INDEX hmacauth_credentials_username(username),
        INDEX hmacauth_credentials_consumer_id(consumer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE hmacauth_credentials;
    ]]
  }
}
