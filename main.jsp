<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    // 내가 팔로우하는 사람들 (비밀계정 타임라인 필터용)
    Set<String> myFollowings = new HashSet<String>();
    if (currentUser != null) {
        String fsql = "SELECT follower_id FROM followings WHERE user_id = ?";
        try (PreparedStatement fps = con.prepareStatement(fsql)) {
            fps.setString(1, currentUser);
            try (ResultSet frs = fps.executeQuery()) {
                while (frs.next()) {
                    myFollowings.add(frs.getString(1));
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // 현재 로그인 유저 정보
    String myStatus = null;
    String myPaidStr = null;
    String myPrivateStr = "F";
    if (currentUser != null) {
        String meSql =
            "SELECT status_message, paid, is_private " +
            "FROM users WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(meSql)) {
            ps.setString(1, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    myStatus     = rs.getString("status_message");
                    myPaidStr    = rs.getString("paid");
                    myPrivateStr = rs.getString("is_private");
                    if (myPrivateStr == null) myPrivateStr = "F";
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    boolean myPaid    = "T".equals(myPaidStr);
    boolean myPrivate = "T".equals(myPrivateStr);

    // 알 수도 있는 사람 목록
    class SuggestUser {
        String userId;
        String status;
        String paid;
    }
    List<SuggestUser> suggests = new ArrayList<SuggestUser>();

    if (currentUser != null) {
        String sugSql =
            "SELECT u.user_id, u.status_message, u.paid " +
            "FROM users u " +
            "WHERE u.user_id <> ? " +
            "  AND u.user_id NOT IN (SELECT follower_id FROM followings WHERE user_id = ?) " +
            "ORDER BY RAND() " +
            "LIMIT 10";
        try (PreparedStatement ps = con.prepareStatement(sugSql)) {
            ps.setString(1, currentUser);
            ps.setString(2, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SuggestUser su = new SuggestUser();
                    su.userId = rs.getString("user_id");
                    su.status = rs.getString("status_message");
                    su.paid   = rs.getString("paid");
                    suggests.add(su);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // 타임라인 게시글
    class TimelinePost {
        String postId;
        String content;
        int    likes;
        int    commentCount;
        String writerId;
        String writerStatus;
        String writerPaid;
        String writerPrivate;
    }
    List<TimelinePost> timeline = new ArrayList<TimelinePost>();

    String postSql =
        "SELECT p.post_id, p.content, p.num_of_likes, " +
        "       u.user_id AS writer_id, u.status_message, u.paid, u.is_private, " +
        "       (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comment_count " +
        "FROM posts p " +
        "JOIN users u ON u.user_id = p.writer_id " +
        "ORDER BY p.post_id DESC";

    try (PreparedStatement ps = con.prepareStatement(postSql);
         ResultSet rs = ps.executeQuery()) {

        while (rs.next()) {
            String writerId   = rs.getString("writer_id");
            String priv       = rs.getString("is_private");
            boolean writerPrivate = "T".equals(priv);

            // 비밀 계정 필터
            boolean canSee = true;
            if (writerPrivate) {
                if (currentUser == null) {
                    canSee = false;
                } else if (!currentUser.equals(writerId) && !myFollowings.contains(writerId)) {
                    canSee = false;
                }
            }
            if (!canSee) continue;

            TimelinePost tp = new TimelinePost();
            tp.postId        = rs.getString("post_id");
            tp.content       = rs.getString("content");
            tp.likes         = rs.getInt("num_of_likes");
            tp.commentCount  = rs.getInt("comment_count");
            tp.writerId      = writerId;
            tp.writerStatus  = rs.getString("status_message");
            tp.writerPaid    = rs.getString("paid");
            tp.writerPrivate = priv;
            timeline.add(tp);
        }
    } catch (Exception e) {
        e.printStackTrace();
    }

    String currentInitial = "G";
    if (currentUser != null && currentUser.length() > 0) {
        currentInitial = currentUser.substring(0,1).toUpperCase();
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>TWITTER_DB4 타임라인</title>
    <link rel="stylesheet" href="style.css">

    <style>
        .home-layout {
            display: flex;
            justify-content: center;
            gap: 16px;
            margin-top: 16px;
        }
        .home-main {
            flex: 0 0 680px;
            max-width: 680px;
        }
        .home-side {
            flex: 0 0 320px;
            max-width: 320px;
        }
        @media (max-width: 960px) {
            .home-layout {
                flex-direction: column;
            }
            .home-main,
            .home-side {
                flex: 1 1 auto;
                max-width: 100%;
                margin: 0 8px;
            }
        }

        /* 글쓰기 텍스트 영역: 댓글 인풋 느낌으로 */
        .post-input-textarea {
            width: 100%;
            border: 1px solid #dddfe2;
            border-radius: 18px;
            padding: 10px 12px;
            font-size: 14px;
            resize: none;
            min-height: 100px;
            box-sizing: border-box;
            outline: none;
        }
        .post-input-textarea:focus {
            border-color: #1877f2;
            box-shadow: 0 0 0 1px #1877f2;
        }

        /* 좋아요 + 댓글 입력 + 게시를 한 줄에 */
        .post-actions-row {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 8px;
        }
        .post-actions-row .comment-inline-form {
            display: flex;
            flex: 1;
            gap: 8px;
            margin: 0;
        }
        .post-actions-row .comment-input {
            flex: 1;
        }
        .post-actions-row .comment-input[disabled] {
            opacity: 0.7;
        }
    </style>
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <!-- 사용자 검색 (비로그인도 프로필 보는 건 가능하게) -->
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn">⚙</a>
                <a href="login.jsp" class="icon-btn">💬</a>
            <%
                } else {
            %>
                <!-- 여기! 프로필 아이콘 왼쪽에 검색 -->
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= currentInitial %></a>
                <a href="settings.jsp" class="icon-btn" title="설정">⚙</a>
                <a href="messages.jsp" class="icon-btn" title="메시지">💬</a>
            <%
                }
            %>
        </div>
    </header>

    <div class="home-layout">

        <!-- 가운데: 글쓰기 + 타임라인 -->
        <div class="home-main">

            <!-- 글쓰기 카드 -->
            <div class="card post-input-card">
                <%
                    if (currentUser == null) {
                %>
                    <div class="helper-text">
                        <a href="login.jsp" class="post-meta-link">로그인</a> 후 글을 작성할 수 있습니다
                    </div>
                <%
                    } else {
                        String myInit = currentUser.substring(0,1).toUpperCase();
                %>
                <!-- 유저 정보 (아이콘 + 이름 + 체크 + 상태메시지) -->
                <div class="post-header">
                    <div class="post-user">
                        <div class="avatar-sm"><%= myInit %></div>
                        <div>
                            <div class="post-username-row">
                                <span class="username-link"><%= currentUser %></span>
                                <%
                                    if (myPaid) {
                                %>
                                    <span class="badge-check">✓</span>
                                <%
                                    }
                                    if (myPrivate) {
                                %>
                                    <span class="badge-pill">🔒</span>
                                <%
                                    }
                                %>
                            </div>
                            <div class="post-meta">
                                <%= (myStatus == null || myStatus.trim().isEmpty())
                                        ? "상태메시지 없음"
                                        : myStatus %>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 안내 텍스트 -->
                <div class="post-input-title" style="margin-top:10px; margin-bottom:6px;">
                    무슨 생각을 하고 계신가요
                </div>

                <!-- 글쓰기 입력 -->
                <form method="post" action="createPost.jsp" class="post-input-form">
                    <textarea name="content" class="post-input-textarea"
                              placeholder="지금 무슨 생각을 하고 계신가요" required></textarea>
                    <div class="post-input-footer">
                        <span class="helper-text">
                            글을 작성하면 타임라인에 게시됩니다
                        </span>
                        <button type="submit" class="btn-primary">게시</button>
                    </div>
                </form>
                <%
                    }
                %>
            </div>

            <!-- 타임라인 -->
            <div class="card">
                <div class="section-title">타임라인</div>

                <%
                    if (timeline.isEmpty()) {
                %>
                    <div class="helper-text">표시할 게시글이 없습니다</div>
                <%
                    } else {
                        for (TimelinePost tp : timeline) {
                            String wid   = tp.writerId;
                            String wInit = wid.substring(0,1).toUpperCase();
                            boolean wPaid    = "T".equals(tp.writerPaid);
                            boolean wPrivate = "T".equals(tp.writerPrivate);
                %>
                <article class="post-card">
                    <div class="post-header">
                        <div class="post-user">
                            <a href="profile.jsp?user=<%= wid %>" class="avatar-sm-link">
                                <div class="avatar-sm"><%= wInit %></div>
                            </a>
                            <div>
                                <div class="post-username-row">
                                    <a href="profile.jsp?user=<%= wid %>" class="username-link"><%= wid %></a>
                                    <%
                                        if (wPaid) {
                                    %>
                                    <span class="badge-check">✓</span>
                                    <%
                                        }
                                        if (wPrivate) {
                                    %>
                                    <span class="badge-pill"></span>
                                    <%
                                        }
                                    %>
                                </div>
                                <div class="post-meta">
                                    <%= (tp.writerStatus == null || tp.writerStatus.trim().isEmpty())
                                            ? "상태메시지 없음"
                                            : tp.writerStatus %>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="post-content">
                        <a href="postDetail.jsp?post_id=<%= tp.postId %>"
                           style="color:#050505; text-decoration:none;">
                            <%= (tp.content == null ? "" : tp.content) %>
                        </a>
                    </div>

                    <div class="post-footer-row">
                        <span class="post-meta-item">post_id <strong><%= tp.postId %></strong></span>
                        <span class="post-meta-item">좋아요 <strong><%= tp.likes %></strong>개</span>
                        <span class="post-meta-item">댓글 <strong><%= tp.commentCount %></strong>개</span>
                        <a href="postDetail.jsp?post_id=<%= tp.postId %>" class="post-meta-link">
                            댓글 포함 자세히 보기
                        </a>
                    </div>

                    <!-- 좋아요 + 댓글 입력 + 게시 -->
                    <div class="post-actions-row">
                        <%
                            if (currentUser == null) {
                        %>
                            <a href="login.jsp" class="btn-secondary btn-sm">좋아요</a>
                            <input type="text" class="comment-input"
                                   placeholder="로그인 후 댓글을 입력할 수 있습니다" disabled>
                        <%
                            } else {
                        %>
                            <form method="post" action="likePost.jsp" style="margin:0; display:inline;">
                                <input type="hidden" name="post_id" value="<%= tp.postId %>">
                                <button type="submit" class="btn-secondary btn-sm">좋아요</button>
                            </form>
                            <form method="post" action="createComment.jsp"
                                  class="comment-inline-form">
                                <input type="hidden" name="post_id" value="<%= tp.postId %>">
                                <input type="text" name="content" class="comment-input"
                                       placeholder="댓글을 입력하세요" required>
                                <button type="submit" class="btn-primary btn-sm">게시</button>
                            </form>
                        <%
                            }
                        %>
                    </div>
                </article>
                <%
                        }
                    }
                %>
            </div>
        </div>

        <!-- 오른쪽: 알 수도 있는 사람 -->
        <div class="home-side">
            <div class="card">
                <div class="section-title">알 수도 있는 사람</div>
                <%
                    if (currentUser == null) {
                %>
                    <div class="helper-text">
                        <a href="login.jsp" class="post-meta-link">로그인</a> 후 팔로우 추천을 볼 수 있습니다
                    </div>
                <%
                    } else if (suggests.isEmpty()) {
                %>
                    <div class="helper-text">추천할 사용자가 없습니다</div>
                <%
                    } else {
                        for (SuggestUser su : suggests) {
                            String uid = su.userId;
                            String init = uid.substring(0,1).toUpperCase();
                            boolean upaid = "T".equals(su.paid);
                %>
                    <div class="user-item">
                        <a href="profile.jsp?user=<%= uid %>" class="avatar-sm-link">
                            <div class="avatar-sm"><%= init %></div>
                        </a>
                        <div class="user-suggest-main">
                            <div class="user-name-row">
                                <a href="profile.jsp?user=<%= uid %>" class="username-link"><%= uid %></a>
                                <%
                                    if (upaid) {
                                %>
                                <span class="badge-check">✓</span>
                                <%
                                    }
                                %>
                            </div>
                            <div class="user-status">
                                <%= (su.status == null || su.status.trim().isEmpty())
                                        ? "상태메시지 없음"
                                        : su.status %>
                            </div>
                        </div>
                        <form method="post" action="followUser.jsp" style="margin:0;">
                            <input type="hidden" name="target_id" value="<%= uid %>">
                            <button type="submit" class="btn-primary btn-xs">팔로우</button>
                        </form>
                    </div>
                <%
                        }
                    }
                %>
            </div>
        </div>

    </div><!-- /.home-layout -->

</div>
</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>
