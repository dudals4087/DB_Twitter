<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.UUID, java.net.URLEncoder" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    if (currentUser == null || currentUser.trim().isEmpty()) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    String reqId  = request.getParameter("req_id");
    String action = request.getParameter("action");
    if (reqId != null)  reqId  = reqId.trim();
    if (action != null) action = action.trim();

    if (reqId == null || reqId.isEmpty() ||
        action == null || action.isEmpty()) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("profile.jsp");
        return;
    }

    String requester = null;
    String target    = null;

    try {
        // 요청 정보 가져오기
        String q =
            "SELECT requester_id, target_id " +
            "FROM follow_requests WHERE req_id = ?";
        try (PreparedStatement ps = con.prepareStatement(q)) {
            ps.setString(1, reqId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    requester = rs.getString("requester_id");
                    target    = rs.getString("target_id");
                }
            }
        }

        if (requester == null || target == null || !currentUser.equals(target)) {
            // 내가 대상이 아닌 요청이면 무시
            if (con != null) {
                try { con.close(); } catch (Exception ignore) {}
            }
            response.sendRedirect("profile.jsp");
            return;
        }

        boolean oldAuto = con.getAutoCommit();
        con.setAutoCommit(false);

        try {
            if ("approve".equalsIgnoreCase(action)) {
                // 이미 followings에 있는지 확인
                boolean already = false;
                String chk =
                    "SELECT 1 FROM followings " +
                    "WHERE user_id = ? AND follower_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chk)) {
                    ps.setString(1, requester);
                    ps.setString(2, target);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) already = true;
                    }
                }

                if (!already) {
                    // 팔로우 확정  followings에만 넣어도 기능은 돌아감
                    String fid = "fw" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
                    String ins =
                        "INSERT INTO followings (f_id, user_id, follower_id) " +
                        "VALUES (?, ?, ?)";
                    try (PreparedStatement ps = con.prepareStatement(ins)) {
                        ps.setString(1, fid);
                        ps.setString(2, requester); // 팔로우 하는 사람
                        ps.setString(3, target);    // 내 계정
                        ps.executeUpdate();
                    }
                }

                // 요청은 제거
                String del =
                    "DELETE FROM follow_requests WHERE req_id = ?";
                try (PreparedStatement ps = con.prepareStatement(del)) {
                    ps.setString(1, reqId);
                    ps.executeUpdate();
                }

            } else if ("reject".equalsIgnoreCase(action)) {
                // 그냥 요청만 삭제
                String del =
                    "DELETE FROM follow_requests WHERE req_id = ?";
                try (PreparedStatement ps = con.prepareStatement(del)) {
                    ps.setString(1, reqId);
                    ps.executeUpdate();
                }
            }

            con.commit();
            con.setAutoCommit(oldAuto);
        } catch (Exception e) {
            con.rollback();
            con.setAutoCommit(true);
            throw e;
        }

    } catch (Exception e) {
        e.printStackTrace();
    } finally {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
    }

    // 내 프로필로 돌아가기
    response.sendRedirect("profile.jsp");
%>
