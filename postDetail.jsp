<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean)session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String postId = request.getParameter("post_id");
    if (postId != null) postId = postId.trim();

    String errorMsg = null;

    if (postId == null || postId.isEmpty()) {
        errorMsg = "게시글 ID가 없습니다";
    }

    String writerId      = null;
    String writerStatus  = null;
    String writerPaid    = null;
    String writerPrivate = "F";
    String postContent   = null;
    int    likeCount     = 0;
    int    commentCount  = 0;

    boolean alreadyFollowing = false;

    // 댓글 노드
    class CommentNode {
        String id;
        String writerId;
        String content;
        int    likes;
        String writerStatus;
        String writerPaid;
        String parentId;
        List<CommentNode> children = new ArrayList<CommentNode>();
    }

    Map<String,CommentNode> commentMap = new LinkedHashMap<String,CommentNode>();
    List<CommentNode> roots = new ArrayList<CommentNode>();

    // 평탄화용 (댓글 + 깊이)
    class CommentWithDepth {
        CommentNode node;
        int depth;
        CommentWithDepth(CommentNode n, int d) { node = n; depth = d; }
    }
    List<CommentWithDepth> flatComments = new ArrayList<CommentWithDepth>();

    try {
        if (errorMsg == null) {
            // 게시글 + 작성자 정보
            String psql =
                "SELECT p.post_id, p.content, p.num_of_likes, " +
                "       u.user_id, u.status_message, u.paid, u.is_private " +
                "FROM posts p " +
                "JOIN users u ON u.user_id = p.writer_id " +
                "WHERE p.post_id = ?";
            try (PreparedStatement ps = con.prepareStatement(psql)) {
                ps.setString(1, postId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        writerId      = rs.getString("user_id");
                        writerStatus  = rs.getString("status_message");
                        writerPaid    = rs.getString("paid");
                        writerPrivate = rs.getString("is_private");
                        if (writerPrivate == null) writerPrivate = "F";

                        postContent   = rs.getString("content");
                        likeCount     = rs.getInt("num_of_likes");
                    } else {
                        errorMsg = "해당 게시글을 찾을 수 없습니다";
                    }
                }
            }
        }

        boolean profilePrivate = "T".equals(writerPrivate);

        // 비밀 계정이면 팔로우 여부 확인
        if (errorMsg == null && profilePrivate && currentUser != null && !currentUser.equals(writerId)) {
            String chk =
                "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
            try (PreparedStatement ps = con.prepareStatement(chk)) {
                ps.setString(1, currentUser);
                ps.setString(2, writerId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) alreadyFollowing = true;
                }
            }
        }

        if (errorMsg == null && profilePrivate) {
            if (currentUser == null || (!currentUser.equals(writerId) && !alreadyFollowing)) {
                errorMsg = "비밀계정이에요 팔로우한 사람만 게시글을 볼 수 있습니다";
            }
        }

        // 댓글들
        if (errorMsg == null) {
            String csql =
                "SELECT c.comment_id, c.content, c.writer_id, c.num_of_likes, c.parent_id, " +
                "       u.status_message, u.paid " +
                "FROM comments c " +
                "JOIN users u ON u.user_id = c.writer_id " +
                "WHERE c.post_id = ? " +
                "ORDER BY c.comment_id ASC";
            try (PreparedStatement ps = con.prepareStatement(csql)) {
                ps.setString(1, postId);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        CommentNode node = new CommentNode();
                        node.id           = rs.getString("comment_id");
                        node.content      = rs.getString("content");
                        node.writerId     = rs.getString("writer_id");
                        node.likes        = rs.getInt("num_of_likes");
                        node.parentId     = rs.getString("parent_id");
                        node.writerStatus = rs.getString("status_message");
                        node.writerPaid   = rs.getString("paid");
                        commentMap.put(node.id, node);
                        commentCount++;
                    }
                }
            }

            // 트리 구성
            for (CommentNode node : commentMap.values()) {
                if (node.parentId == null || node.parentId.trim().isEmpty()) {
                    roots.add(node);
                } else {
                    CommentNode parent = commentMap.get(node.parentId);
                    if (parent != null) parent.children.add(node);
                    else roots.add(node); // 부모 못 찾으면 루트로
                }
            }

            // 트리 -> (node, depth) 리스트로 평탄화 (DFS)
            java.util.Deque<CommentWithDepth> stack = new java.util.ArrayDeque<CommentWithDepth>();
            for (int i = roots.size() - 1; i >= 0; --i) {
                stack.push(new CommentWithDepth(roots.get(i), 0));
            }
            while (!stack.isEmpty()) {
                CommentWithDepth cwd = stack.pop();
                flatComments.add(cwd);
                List<CommentNode> childs = cwd.node.children;
                for (int i = childs.size() - 1; i >= 0; --i) {
                    stack.push(new CommentWithDepth(childs.get(i), cwd.depth + 1));
                }
            }
        }

    } catch (Exception e) {
        e.printStackTrace();
        if (errorMsg == null) errorMsg = "게시글을 불러오는 중 오류가 발생했습니다";
    }

    boolean writerPaidBool    = "T".equals(writerPaid);
    boolean writerPrivateBool = "T".equals(writerPrivate);

    String writerInitial = "U";
    if (writerId != null && writerId.length() > 0) {
        writerInitial = writerId.substring(0,1).toUpperCase();
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
    <title>게시글 상세  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">게시글 상세</div>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn">⚙</a>
                <a href="login.jsp" class="icon-btn">💬</a>
            <%
                } else {
            %>
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= currentInitial %></a>
                <a href="settings.jsp" class="icon-btn">⚙</a>
                <a href="messages.jsp" class="icon-btn">💬</a>
            <%
                }
            %>
        </div>
    </header>

    <div class="center-layout">
        <section class="center-column">
            <div class="card">
                <!-- 타임라인으로 돌아가기 -->
                <form action="main.jsp" method="get" style="margin-bottom:12px;">
                    <button type="submit" class="btn-secondary btn-sm">
                        ← 타임라인으로 돌아가기
                    </button>
                </form>

                <%
                    if (errorMsg != null) {
                %>
                    <div class="msg msg-err"><%= errorMsg %></div>
                <%
                    } else {
                %>

                <!-- 게시글 영역 -->
                <article class="post-card">
                    <div class="post-header">
                        <div class="post-user">
                            <a href="profile.jsp?user=<%= writerId %>" class="avatar-sm-link">
                                <div class="avatar-sm"><%= writerInitial %></div>
                            </a>
                            <div>
                                <div class="post-username-row">
                                    <a href="profile.jsp?user=<%= writerId %>" class="username-link"><%= writerId %></a>
                                    <%
                                        if (writerPaidBool) {
                                    %>
                                        <span class="badge-check">✓</span>
                                    <%
                                        }
                                    %>
                                    <%
                                        if (writerPrivateBool) {
                                    %>
                                        <span class="badge-pill">🔒</span>
                                    <%
                                        } else {
                                    %>
                                        <span class="badge-pill badge-light"></span>
                                    <%
                                        }
                                    %>
                                </div>
                                <div class="post-meta">
                                    <%= (writerStatus == null || writerStatus.trim().isEmpty())
                                            ? "상태메시지 없음"
                                            : writerStatus %>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="post-content">
                        <%= (postContent == null ? "" : postContent) %>
                    </div>

                    <div class="post-footer-row">
                        <span class="post-meta-item">post_id <strong><%= postId %></strong></span>
                        <span class="post-meta-item">좋아요 <strong><%= likeCount %></strong>개</span>
                        <span class="post-meta-item">댓글 <strong><%= commentCount %></strong>개</span>
                    </div>

                    <div class="post-footer-row">
                        <!-- 좋아요 버튼 -->
                        <form method="post" action="likePost.jsp" style="display:inline;">
                            <input type="hidden" name="post_id" value="<%= postId %>">
                            <button type="submit" class="btn-like">좋아요</button>
                        </form>

                        <!-- 게시글 삭제 버튼: 작성자만 -->
                        <%
                            if (currentUser != null && currentUser.equals(writerId)) {
                        %>
                            <form method="post" action="deletePost.jsp"
                                  style="display:inline; margin-left:8px;"
                                  onsubmit="return confirm('이 게시글을 삭제할까요? 댓글도 함께 삭제됩니다');">
                                <input type="hidden" name="post_id" value="<%= postId %>">
                                <button type="submit" class="btn-danger btn-sm">게시글 삭제</button>
                            </form>
                        <%
                            }
                        %>
                    </div>
                </article>

                <hr class="divider">

                <!-- 댓글 쓰기 -->
                <div class="section-title">댓글 쓰기</div>
                <form method="post" action="createComment.jsp">
                    <input type="hidden" name="post_id" value="<%= postId %>">
                    <input type="hidden" name="parent_id" value="">
                    <div class="comment-write-row">
                        <div class="avatar-sm"><%= (currentUser == null ? "?" :
                                currentUser.substring(0,1).toUpperCase()) %></div>
                        <input type="text" name="content" class="comment-input"
                               placeholder="댓글을 입력하세요">
                        <button type="submit" class="btn-primary btn-sm">댓글 게시</button>
                    </div>
                </form>

                <div class="section-title" style="margin-top:16px;">댓글 <%= commentCount %>개</div>

                <!-- 댓글 리스트 -->
                <div class="comment-list">
                    <%
                        for (CommentWithDepth cwd : flatComments) {
                            CommentNode node = cwd.node;
                            int depth = cwd.depth;
                            String init = node.writerId.substring(0,1).toUpperCase();
                            boolean paid = "T".equals(node.writerPaid);
                            String indentStyle = "padding-left:" + (depth * 28) + "px;";
                            String st = (node.writerStatus == null || node.writerStatus.trim().isEmpty())
                                        ? "상태메시지 없음" : node.writerStatus;
                    %>
                    <div class="comment-block" style="<%= indentStyle %>">
                        <div class="comment-header">
                            <a href="profile.jsp?user=<%= node.writerId %>" class="avatar-sm-link">
                                <div class="avatar-sm"><%= init %></div>
                            </a>
                            <div class="comment-user-main">
                                <div class="post-username-row">
                                    <a class="username-link" href="profile.jsp?user=<%= node.writerId %>"><%= node.writerId %></a>
                                    <%
                                        if (paid) {
                                    %>
                                        <span class="badge-check">✓</span>
                                    <%
                                        }
                                    %>
                                </div>
                                <div class="post-meta"><%= st %></div>
                            </div>
                        </div>

                        <div class="comment-content">
                            <%= (node.content == null ? "" : node.content) %>
                        </div>

                        <div class="comment-meta-row">
                            comment_id <strong><%= node.id %></strong>
                            좋아요 <strong><%= node.likes %></strong>개
                        </div>

                        <div class="comment-actions-row">
                            <!-- 댓글 좋아요 -->
                            <form method="post" action="likeComment.jsp" style="display:inline;">
                                <input type="hidden" name="comment_id" value="<%= node.id %>">
                                <input type="hidden" name="post_id" value="<%= postId %>">
                                <button type="submit" class="btn-like btn-xs">좋아요</button>
                            </form>

                            <!-- 답글 -->
                            <form method="post" action="createComment.jsp"
                                  style="display:inline; margin-left:8px;">
                                <input type="hidden" name="post_id" value="<%= postId %>">
                                <input type="hidden" name="parent_id" value="<%= node.id %>">
                                <input type="text" name="content" class="reply-input"
                                       placeholder="답글을 입력하세요">
                                <button type="submit" class="btn-primary btn-xs">답글</button>
                            </form>

                            <!-- 댓글 삭제: 작성자만 -->
                            <%
                                if (currentUser != null && currentUser.equals(node.writerId)) {
                            %>
                            <form method="post" action="deleteComment.jsp"
                                  style="display:inline; margin-left:6px;"
                                  onsubmit="return confirm('이 댓글을 삭제할까요? 대댓글도 함께 삭제됩니다');">
                                <input type="hidden" name="comment_id" value="<%= node.id %>">
                                <input type="hidden" name="post_id" value="<%= postId %>">
                                <button type="submit" class="btn-danger btn-sm">댓글 삭제</button>
                            </form>
                            <%
                                }
                            %>
                        </div>
                    </div>
                    <%
                        } // for flatComments
                    %>
                </div>

                <%
                    } // error else
                %>
            </div>
        </section>
    </div>

</div>
</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>
