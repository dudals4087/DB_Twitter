<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.*, java.net.URLEncoder" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    if (currentUser == null) {
        // 로그인 안 했으면 로그인 페이지로
        response.sendRedirect("login.jsp");
        return;
    }

    String postId   = request.getParameter("post_id");
    String content  = request.getParameter("content");
    String parentId = request.getParameter("parent_id");   // 대댓글이면 여기에 값이 들어옴

    if (postId != null) postId = postId.trim();
    if (content != null) content = content.trim();
    if (parentId != null) parentId = parentId.trim();

    if (postId == null || postId.isEmpty() || content == null || content.isEmpty()) {
        response.sendRedirect("postDetail.jsp?post_id=" + URLEncoder.encode(postId == null ? "" : postId, "UTF-8"));
        return;
    }

    String commentId = "c" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);

    PreparedStatement ps = null;
    try {
        // comments 테이블에 parent_id 컬럼이 추가되어 있어야 함
        String sql =
            "INSERT INTO comments " +
            "  (comment_id, content, writer_id, post_id, num_of_likes, parent_id) " +
            "VALUES (?, ?, ?, ?, 0, ?)";

        ps = con.prepareStatement(sql);
        ps.setString(1, commentId);
        ps.setString(2, content);
        ps.setString(3, currentUser);
        ps.setString(4, postId);

        if (parentId == null || parentId.isEmpty()) {
            ps.setNull(5, Types.VARCHAR);      // 일반 댓글
        } else {
            ps.setString(5, parentId);         // 대댓글: 부모 댓글 id
        }

        ps.executeUpdate();

    } catch (Exception e) {
        e.printStackTrace();
        // 에러 나도 일단 상세 페이지로 되돌리기
    } finally {
        if (ps != null) try { ps.close(); } catch (Exception ignore) {}
        if (con != null) try { con.close(); } catch (Exception ignore) {}
    }

    response.sendRedirect("postDetail.jsp?post_id=" + URLEncoder.encode(postId, "UTF-8"));
%>
