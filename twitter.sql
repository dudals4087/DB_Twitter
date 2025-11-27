DROP DATABASE IF EXISTS twitter;
CREATE DATABASE twitter;
USE twitter;

CREATE TABLE users (
  user_id VARCHAR(30) NOT NULL PRIMARY KEY,
  pwd VARCHAR(15) NOT NULL,
  paid ENUM('T','F') NOT NULL DEFAULT 'F',
  address VARCHAR(30),
  phone_number VARCHAR(13),
  status_message VARCHAR(150) NULL,
  UNIQUE (phone_number)
);

CREATE TABLE posts (
  post_id VARCHAR(30) NOT NULL PRIMARY KEY,
  content TEXT,
  writer_id VARCHAR(30) NOT NULL,
  num_of_likes INT,
  FOREIGN KEY (writer_id) REFERENCES users(user_id)
);

CREATE TABLE comments (
  comment_id VARCHAR(30) NOT NULL PRIMARY KEY,
  content TEXT,
  writer_id VARCHAR(30) NOT NULL,
  post_id VARCHAR(30) NOT NULL,
  num_of_likes INT,
  FOREIGN KEY (writer_id) REFERENCES users(user_id),
  FOREIGN KEY (post_id) REFERENCES posts(post_id)
);

CREATE TABLE post_likes (
  l_id VARCHAR(30) NOT NULL PRIMARY KEY,
  post_id VARCHAR(30) NOT NULL,
  liker_id VARCHAR(30) NOT NULL,
  FOREIGN KEY (post_id) REFERENCES posts(post_id),
  FOREIGN KEY (liker_id) REFERENCES users(user_id),
  CONSTRAINT uq_post_like UNIQUE (post_id, liker_id)
);

CREATE TABLE comment_likes (
  l_id VARCHAR(30) NOT NULL PRIMARY KEY,
  comment_id VARCHAR(30) NOT NULL,
  liker_id VARCHAR(30) NOT NULL,
  FOREIGN KEY (comment_id) REFERENCES comments(comment_id),
  FOREIGN KEY (liker_id) REFERENCES users(user_id),
  CONSTRAINT uq_comment_like UNIQUE (comment_id, liker_id)
);

CREATE TABLE follower (
  f_id VARCHAR(30) NOT NULL PRIMARY KEY,
  user_id VARCHAR(30) NOT NULL,
  follower_id VARCHAR(30) NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT uq_follower UNIQUE (user_id, follower_id),
  CONSTRAINT chk_self_follow_1 CHECK (user_id <> follower_id)
);

CREATE TABLE followings (
  f_id VARCHAR(30) NOT NULL PRIMARY KEY,
  user_id VARCHAR(30) NOT NULL,
  follower_id VARCHAR(30) NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT uq_followings UNIQUE (user_id, follower_id),
  CONSTRAINT chk_self_follow_2 CHECK (user_id <> follower_id)
);

CREATE TABLE message (
  m_id VARCHAR(30) NOT NULL PRIMARY KEY,
  sender VARCHAR(30) NOT NULL,
  receiver VARCHAR(30) NOT NULL,
  content TEXT,
  FOREIGN KEY (sender) REFERENCES users(user_id),
  FOREIGN KEY (receiver) REFERENCES users(user_id)
);

CREATE TABLE subscriptions (
  p_id VARCHAR(40) PRIMARY KEY,
  user_id VARCHAR(30) NOT NULL,
  period INT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);

INSERT INTO users VALUES
('harry','123@%','T', 'seoul', '010-1111-1111', 'poter'),
('james','qhdks365!','F', 'seoul', '010-2222-2222', NULL),
('trump','qhdks365!','T', 'washington', '010-3333-3333', 'MAGA'),
('obama','qhdks365!','T', 'newyork', '010-4444-4444', 'Buruk'),
('nick','qhdks365!','F', 'busan', '010-5555-5555', NULL),
('otani','qhdks365!','T', 'LA', '010-6666-6666', 'Champion');

INSERT INTO posts VALUES
('p1','hello world','james',10),
('p2','MAGA','trump',1000),
('p3','god of baseball','otani',1000000);

INSERT INTO comments VALUES
('c1','hello','nick','p1',2),
('c2','wow','obama','p2',10),
('c3','happy','harry','p3',100);

INSERT INTO follower VALUES
('f1','james','harry'),
('f2','obama','trump'),
('f3','otani','nick');

INSERT INTO followings VALUES
('f1','james','harry'),
('f2','obama','trump'),
('f3','otani','nick');

ALTER TABLE message
  ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
  
  CREATE TABLE replies (
  reply_id   VARCHAR(30) NOT NULL PRIMARY KEY,
  comment_id VARCHAR(30) NOT NULL,
  writer_id  VARCHAR(30) NOT NULL,
  content    TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (comment_id) REFERENCES comments(comment_id),
  FOREIGN KEY (writer_id)  REFERENCES users(user_id)
);

ALTER TABLE users
  ADD COLUMN is_private ENUM('T','F') NOT NULL DEFAULT 'F';

CREATE TABLE follow_requests (
  req_id      VARCHAR(30) PRIMARY KEY,
  requester_id VARCHAR(30) NOT NULL,  -- 팔로우 신청을 한 사람
  target_id    VARCHAR(30) NOT NULL,  -- 팔로우 당하는 계정 (계정 주인)
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (requester_id, target_id),
  FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (target_id)    REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT chk_self_follow_req CHECK (requester_id <> target_id)
);

ALTER TABLE comments
    ADD COLUMN parent_id VARCHAR(30) NULL AFTER post_id;

ALTER TABLE comments
    ADD CONSTRAINT fk_comment_parent
        FOREIGN KEY (parent_id) REFERENCES comments(comment_id)
        ON DELETE CASCADE;

SELECT * FROM users;
SELECT * FROM posts;
SELECT * FROM follower;
SELECT * FROM followings;
SELECT * FROM comments;
SELECT * FROM message;
SELECT * FROM subscriptions;