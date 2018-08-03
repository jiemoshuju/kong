return {
  {
    name = "2015-07-31-172400_init_keyauth",
    up = [[
        CREATE TABLE IF NOT EXISTS keyauth_credentials(
        id varchar(50),
        consumer_id varchar(50),
        `key` varchar(100) UNIQUE,
        created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT keyauth_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE ,  
        PRIMARY KEY (id),
        INDEX keyauth_key_idx(`key`),
        INDEX keyauth_consumer_idx(consumer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE keyauth_credentials;
    ]]
  }
}
