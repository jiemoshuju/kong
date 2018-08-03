return {
  {
    name = "2015-08-03-132400_init_basicauth",
    up = [[
        CREATE TABLE IF NOT EXISTS basicauth_credentials(
        id varchar(50),
        consumer_id varchar(50) ,
        username varchar(100) UNIQUE,
        password varchar(100),
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        CONSTRAINT basicauth_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE , 
        INDEX basicauth_username_idx(username),
        INDEX basicauth_consumer_id_idx(consumer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down =  [[
      DROP TABLE basicauth_credentials;
    ]]
  } 
}
