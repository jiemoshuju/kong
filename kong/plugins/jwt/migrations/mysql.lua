return {
  {
    name = "2015-06-09-jwt-auth",
    up = [[
      CREATE TABLE IF NOT EXISTS jwt_secrets(
        id varchar(50),
        consumer_id varchar(50) ,
        `key` varchar(100) UNIQUE,
        secret varchar(500) UNIQUE,
        algorithm varchar(100),
        rsa_public_key varchar(200),
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        CONSTRAINT jwt_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE , 
        INDEX jwt_secrets_key(`key`),
        INDEX jwt_secrets_secret(secret),
        INDEX jwt_secrets_consumer_id(consumer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE jwt_secrets;
    ]]
  } 
}
