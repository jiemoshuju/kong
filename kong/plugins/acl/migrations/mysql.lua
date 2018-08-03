return {
  {
    name = "2015-08-25-841841_init_acl",
    up = [[
      CREATE TABLE IF NOT EXISTS acls(
        id varchar(50) NOT NULL,
        consumer_id varchar(50),
        `group` varchar(500),
        created_at timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        CONSTRAINT acls_consumerid_fk FOREIGN KEY (consumer_id) REFERENCES consumers(id) ON DELETE CASCADE , 
        INDEX acls_group(`group`),
        INDEX acls_consumer_id(consumer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;
    ]],
    down = [[
      DROP TABLE acls;
    ]]
  }
}
